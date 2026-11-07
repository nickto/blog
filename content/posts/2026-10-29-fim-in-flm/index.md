---
title: "Get inline suggestions from a model on AMD NPU"
date: 2026-10-29T12:30:49+02:00
draft: true
---

My GitHub Copilot subscription, paid for by a previous employer, has recently
ended. So before paying for it out of my own pocket, I decided to check whether
I can run a local model for inline suggestions: these do not require powerful
models, after all. And yes, of course, you can. But even running it on a GPU is
trickier than I expected, not to mention running it on an NPU.

## Fill-in-the-middle

We are mostly used to chat models that generate text left-to-right: the next
token is generated using the context that precedes it. Inline suggestions
are slightly different: both the context before and after the cursor matter.
E.g., for a docstring we need to know both the function name with arguments and
the function code.

Models used for this type of task are commonly trained with the
_fill-in-the-middle_ (FIM) objective, proposed by [Bavarian, M., et al. in
2022](https://arxiv.org/abs/2207.14255). This is not a different model
architecture, but rather a different training objective, where given the text
before and after the missing part, the model should fill in the missing part. 

Technically, most LLMs should be able to do the task if we describe what we
expect from them in the prompt. But this is very chatty, less efficient, and
more likely to produce an output format we do not expect. For this reason,
inline suggestion tools format their requests to LLMs in a special FIM format.
However, not all models understand it because in order to do so, the model
should have been trained on this format. So we need to narrow down the list of
models to the ones that were.

Given the aspects which I will discuss in the NPU section, I will just mention
that [Qwen2.5-Coder-3B](https://huggingface.co/Qwen/Qwen2.5-Coder-3B) is one of
these models.

## GPU

Running on GPU, regardless of whether it is discrete or integrated, is
straightforward: just find a suitable model and serve with
[llama.cpp](https://github.com/ggml-org/llama.cpp) using the backend that your
GPU supports.

### Vulkan vs ROCm

I have an integrated Radeon 890M, which supports both Vulkan and ROCm on Linux, 
so I have to pick.

**Vulkan** is a cross-vendor, low-level graphics API that also supports compute
shaders. llama.cpp's Vulkan backend expresses the same operations as generic
shaders, which the driver then compiles for whatever GPU is there.

**ROCm** is AMD's GPU compute platform, an answer to NVIDIA's CUDA. Its main
programming model is HIP, which looks like CUDA and compiles to code written
specifically for AMD GPU architectures. llama.cpp has a dedicated HIP backend
for it.

Vulkan only needs the regular graphics driver, so it is much easier to set up,
and because it is cross-vendor, it has larger adoption and is more stable. ROCm
is vendor-tuned and targets the hardware directly, so one can expect that
matrix-multiplication should be faster on ROCm. On the flip side, support for
integrated GPUs is often unofficial, and therefore the whole setup can be less
stable and require some fiddling to make it work. For example, the 890M needs
`HSA_OVERRIDE_GFX_VERSION=11.0.0` to make ROCm treat it as an RDNA 3 GPU
(gfx1100) instead of its actual RDNA 3.5 architecture (gfx1150), for which ROCm
has no kernels.

Luckily, llama.cpp has a built-in utility for measuring model throughput, which
I used to benchmark performance:

- across the two backends,
- for two quantization levels,
- across input and output sizes realistic for FIM tasks.

![Prompt processing throughput.](bench_prompt.svg)

![Token generation throughput.](bench_generation.svg)

The main takeaway here is that for inline completions, which typically have long
prompts and short completions, it's prompt processing that is the bottleneck,
and ROCm is noticeably faster for the F16 variant, while Vulkan is faster for Q4_0.

Treat these conclusions with a grain of salt, though. I noticed that the same
parameters can yield wildly different results within the different retries of
the same experiment run. The likely culprit is thermal throttling: giving the
GPU time to cool down between runs seemed to help, and the results become much
more stable. However, I have not tested this hypothesis directly, so I cannot
guarantee that the results shown here are not affected by it, rather than being
stable because they are equally affected.

### Example query and completion

As a quick test of whether it works, I check how models complete the following code:

```python
def add(a, b):
    # Complete here
    return c
```

In the case of Qwen 2 models, this request should be formatted as the following prompt:

```json
"<|fim_prefix|>def add(a, b):\n    <|fim_suffix|>\n    return c<|fim_middle|>"
```

where we first supply the prefix, or the part goes before the completion, then
the suffix, or the part that goes after the completion, and ask the model to
fill in the middle, or the actual completion. So the full request looks like 
this

```json
{
  "model": "<model name>",
  "max_tokens": 32,
  "temperature": 0,
  "prompt": "<|fim_prefix|>def add(a, b):\n    <|fim_suffix|>\n    return c<|fim_middle|>"
}
```

and full `curl` command for the F16 Qwen 2.5 Coder 3B model, looks like this
(assuming that llama.cpp is running on `localhost:8080`):

```bash
curl http://localhost:8080/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
          "model": "qwen2.5-coder-3b-f16",
          "max_tokens": 64,
          "temperature": 0,
          "prompt": "<|fim_prefix|>def add(a, b):\n    <|fim_suffix|>\n    return c<|fim_middle|>"
        }' \
    | jq '.choices[0]'
```

The result is:

```json
{
  "text": "c = a + b\n    return c\n\ndef sub(a, b):\n    c = a - b\n    return c\n\ndef mul(a, b):\n    c = a * b\n    return c\n\ndef div(a, b):\n    c = a / b",
  "index": 0,
  "logprobs": null,
  "finish_reason": "stop"
}
```

which implies that the code after the suggested completion is:

```python
def add(a, b):
    c = a + b
    return c

def sub(a, b):
    c = a - b
    return c

def mul(a, b):
    c = a * b
    return c

def div(a, b):
    c = a / b
    return c    
```

We can discuss whether this exactly what we wanted or not, but at least it is
hard to argue that this is a totally valid completion.

## NPU

Another option is to run on an NPU, e.g., I have an AMD Ryzen AI 9 HX 370, which
has one built in. An NPU (neural processing unit) is an accelerator that is
basically built for efficient matrix multiplication. And neural networks mostly
consist of matrix multiplications, so it is very suitable for running them.
Unlike a GPU, its goal is energy efficiency rather than peak speed.

### NPU vs GPU

A GPU is very flexible: it decides how to schedule the work while it is running,
so it can handle almost any parallel computation. An NPU saves power by having
this decided in advance, when the model is compiled for it. The result is
efficient, but only for the exact computation it was prepared for.

The practical consequence of that is that you cannot just run any model on it,
like on a GPU. Each model has to be specifically prepared for the hardware so
the choice of the models that can run on it is very limited.

### Why bother?

If running models on NPU is hard, why use it at all? Well, the inline
suggestions are a background task: they fire constantly while you type. So
running them on a GPU is hard to miss: its load sits close to 100% almost all of
the time. Its small iGPU cannot heat your whole house, but can work as a good
hand warmer, which is nice. But it drains the battery, which is not nice. And
because NPUs are supposed to be much more energy efficient than GPUs, running
models for such background tasks on NPU sounds very appealing.

### FastFlowLM

Luckily, there is a great project, called [FastFlowLM](https://fastflowlm.com/)
(FLM). It is a runtime for the Ryzen AI NPU. You install it, run something like
`flm serve llama3.2:1b`, and get a local server with an OpenAI-compatible API
that any tool can talk to.

FLM [started in 2025](https://github.com/ROCm/FastFlowLM/blob/main/flm_story.md)
as a university research project and quickly became a small startup. In July
2026, [it officially joined
AMD](https://www.amd.com/en/blogs/2026/fastflowlm-joins-amd-to-advance-ai-inference.html),
and the code now lives in [AMD's ROCm
organization](https://github.com/ROCm/FastFlowLM).

#### The good

FLM offers a pretty [wide choice of smaller
LLMs](https://fastflowlm.com/docs/models/) (and a couple of other neural
networks). 

Among many, they ship:

- [Qwen3.6-35B-A3B](https://fastflowlm.com/docs/models/qwen/#-model-card-qwen36-35b-a3b),
  which is powerful, yet fast, because only a small part of it is used for each
  individual token generation (the "A3B" in the name).
-
  [Qwen2.5-3B](https://fastflowlm.com/docs/models/qwen/#-model-card-qwen25-3b-instruct),
  which is a bit boring in itself, and because it is an Instruct rather than a
  Coder variant, it cannot do FIM. But it is crucial that this model is
  available, because it comes from a family of models that _does_ have a Coder
  variant. And we will use it to run inline suggestions.

The list is constantly being updated, so it's worth keeping an eye on. E.g., last
time I checked,
[Qwen3.8-27B](https://fastflowlm.com/docs/models/qwen/#-model-card-qwen38-27b)
was not there, yet, but is there now.

Moreover, besides the usual `/v1/chat/completions` endpoint, which is used for
chats, FLM also supports the [legacy
`/v1/completions`](https://github.com/ROCm/FastFlowLM/releases/tag/v0.9.13) one,
and this is another crucial piece that makes inline suggestions possible.

The difference between the two endpoints is what happens to your text. The chat
endpoint takes a list of messages, and the server wraps them in the model's chat
template before the model sees them. The completions endpoint takes a raw
prompt, passes it to the model as is, and the model simply continues it.

FIM needs the latter, because a FIM request is not a conversation. It is a
single string that contains the context before and after where we want the
suggestion.

This may sound like a minor detail, but many serverless model providers offer
only the chat endpoint, so you cannot use them for inline completions, even if
the model itself was trained for FIM. Technically, one could find a workaround
maybe, but the existing tools expect the `/v1/completions` endpoint (or an even
less commonly supported `/v1/fim/completions`).

#### The bad

But there is one important caveat: FLM is only partly open source. The
orchestration code and the CLI are
[MIT-licensed](https://github.com/ROCm/FastFlowLM/blob/main/LICENSE_RUNTIME.txt),
but **the NPU kernels are closed binaries**. They are [free for any
use](https://github.com/ROCm/FastFlowLM/blob/main/LICENSE_BINARY.txt), including
commercial, but you cannot read or change them. And these kernels are the part
that actually runs on the NPU, so if the model is not on the list, there is not 
much you can do. At least without jumping through a lot of hoops.

Unfortunately, even though FLM offers quite a few models, none of them are the
FIM capable. So we cannot use an off-the-shelve solution here.

## Converting the model

One way of jumping through the hoops is to reuse the kernels of a model that is
already supported, and only replace the weights. However, this is possible only
if the models share the exact same architecture. This is the approach used in
[this project](https://github.com/ROCm/FLM_Q4NX_Converter).

And we are in luck here again, because the commonly recommended models for
inline completions are the smaller versions of Qwen2.5-Coder. Since
[Qwen2.5-3B-Instruct](https://fastflowlm.com/docs/models/qwen/#-model-card-qwen25-3b-instruct)
is officially supported and has the same architecture as Qwen2.5-Coder-3B, we
can reuse its kernels and convert the Coder weights to Q4NX, the format FLM's
models use.

### The journey from GGUF to Q4NX

#### The naive approach

[FLM Q4NX Converter](https://github.com/ROCm/FLM_Q4NX_Converter) expects a Q4_0
or Q4_1 quantized weights in GGUF format. And the [model's
card](https://fastflowlm.com/docs/models/qwen/#-model-card-qwen25-3b-instruct)
says that is uses the Q4_1 quantization, so we go to
[Huggingace](https://huggingface.co/Qwen/Qwen2.5-Coder-3B), download the
waights, convert them to GGUF, quantize to Q4_1, and convert to Q4NX.

Sounds easy, does not work. The model produces garbage.

Let's look at our smoke test query.

```bash
curl http://localhost:52625/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
          "model": "qwen2.5-coder:3b-q4_1-no-eos-fix",
          "max_tokens": 64,
          "temperature": 0,
          "prompt": "<|fim_prefix|>def add(a, b):\n    <|fim_suffix|>\n    return c<|fim_middle|>"
        }' \
    | jq '.choices[0]'
```

which returns

```json
{
  "text": "EFR<|fim_middle|>[\".té ЮрuratneauEFR<|fim_middle|>getherasil˟odonVISIONEFR<|fim_middle|>ajas[Z Больш={!REPEFR<|fim_middle|>téfieldname[\". ЮрEFR<|fim_middle|>mention НиurattéFirstResponderüst[\". Юр tripeorInputElementzscheEFR<|fim_middle|>DMINphansamaxurat СегодняBusyochtfoonténeauymbhus:\".ики(EFFECT[\". Юр[--・・・\n\nEFR<|fim_middle|>",
  "index": 0,
  "logprobs": null,
  "finish_reason": "length"
}
```

unlike the example we had before, where we might argue whether we wanted 
a completion of just one function, or a whole battery of them, here we have
a clear case of garbage.

#### Q4_1 in, garbage out

First, I thought that this was an issue with the tokenizer or the model
configs. So I tried mixing and matching them, taking some files from the Hugging
Face checkpoint and some from the official NPU2 release. No luck.

Then, before giving up, I asked an LLM what might be wrong (should have done
that first, haha).

To make sense of its answer, we need to know the difference between Q4_0 and
Q4_1 quantization. Both are 4-bit quantization formats: weights are split into
smaller groups, and each weight is stored as a 4-bit integer `q`, which takes a
_nibble_ (half a byte), plus a scale shared by the whole group. What differs is
how a group is turned back into numbers:

- **Q4_0** stores one scale `d` per group and reconstructs a weight as `d * (q -
  8)`. The nibble is effectively signed: 8 (`1000`) means zero, values below it
  are negative, values above it are positive. (This is how GGUF stores it. When
  converting to Q4NX, the converter subtracts the 8 and stores true signed 4-bit
  numbers.)
- **Q4_1** stores an additional offset `m` per group and reconstructs a weight
  as `d * q + m`. The nibble is unsigned, and the offset `m` shifts the whole
  group. Since the offset is a signed float, `q` stays unsigned. When converting
  to Q4NX, the converter copies Q4_1's nibbles unchanged.

The extra parameter makes Q4_1 a bit more precise: on a few sampled tensors, the
relative error of the dequantized weights against the original ones was about
10% lower for Q4_1 than for Q4_0, for about 11% more size. So if the kernel
supports it, there is little reason not to use it.

Instead of guessing further, the LLM went straight to the weights. It wrote a
small decoder for the Q4NX file, and compared the official Qwen2.5-3B-Instruct
with my Q4_1 conversion of the Coder.

The first clue is the offsets. In my Q4_1 conversion, every group has a
non-zero offset, as expected: the offset is the smallest weight in the group,
and that is practically never exactly zero. In the official model, all 96
million groups have an offset of zero. Whatever the official model is, it is not
real Q4_1.

A zero offset alone only says that the offset is not used, though, not what the
format is instead. To find out, the LLM looked at the distribution of the nibble
values. Weights in a group are roughly bell-shaped around their center, so the
most common nibbles show where the encoding puts that center:

- If the nibbles are unsigned, 0 to 15 is one continuous scale, and the
  center lands in the middle: 7 (`0111`) and 8 (`1000`).
- If the nibbles are signed (two's complement), the scale is not continuous: 0
  (`0000`) to 7 (`0111`) represent the values 0 to 7, but then the scale jumps
  and 8 (`1000`) to 15 (`1111`) actually represent −8 to −1. So the
  distribution's center (values around 0) is stored in the nibbles 0 (`0000`),
  +1 (`0001`) and −1 (`1111`). If we try reading them as unsigned, these would
  be 0, 1 and 15: the peak splits across both ends of the scale, and the middle
  is nearly empty.

In my Q4_1 conversion, the nibbles peak at 7 (`0111`) and 8 (`1000`): unsigned,
as Q4_1 should be. In the official model, they peak at 0 (`0000`), 1 (`0001`)
and 15 (`1111`): signed values centered on zero, which need no offset.

One more clue points the same way: about half of the official scales are
negative. A Q4_1 scale is always positive, because it spans the group from its
smallest weight to its largest. A Q4_0 scale can carry a sign.

In other words, the official model does not look like Q4_1 at all. It looks
like Q4_0.

So I converted from Q4_0 instead, and the model started producing code! 🥳

```bash
curl -s http://localhost:52625/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
            "model": "qwen2.5-coder:3b-q4_0-no-eos-fix",
            "max_tokens": 64,
            "temperature": 0,
            "prompt": "<|fim_prefix|>def add(a, b):\n    <|fim_suffix|>\n    return c<|fim_middle|>"
        }' \
    | jq '.choices[0]'
```

returns 

```json
{
  "text": " a + b\n    print(add(1, 2))<|fim_middle|>",
  "index": 0,
  "logprobs": null,
  "finish_reason": "stop"
}
```

Still not perfect (and we will get into this), but it looks like step in the
right direction!

But the model card still said Q4_1. Was the card wrong, or was it just a
coincidence? So we (me and my LLM detective) collected more evidence:

- In FLM's own model registry (`model_list.json`), `qwen2.5-it:3b` is listed as
  `Q4_0`. The same file lists `Q4_1` for other models (e.g., `qwen3` and
  `llama3.2`), so it does distinguish between the two.
- The converter's Qwen2 config has `Q4_0` as the default tensor type.

So the model card is the odd one out. I do not know why it says Q4_1.

What makes this trap particularly nasty is that there are no errors along the
whole pipeline. The converter accepts Q4_1 without a warning and writes a file
of exactly the same size as the Q4_0 one. FLM loads it just fine. It only breaks
inside the closed kernel, which seems to simply ignore the offset: zeroing all
the offsets in my Q4_1 file gave the same garbage, token for token. And the
offset is not a small correction you can afford to lose. It is about 40% of the
weights' magnitude!

### Improving the quality

- EOS tokens
- Embeddings
- AWQ

## Evaluation

- What SAFIM is and why I used it
- Quality: processing variants vs GGUF alternatives (benchmark in progress)
- Speed: NPU vs GPU latency
- Maybe: official Instruct model vs this pipeline
- Maybe: power draw, NPU vs GPU

## Verdict

- Surprisingly good quality
- A bit slow: latency on the GPU is better
- The answer to the opening question: is it worth using instead of Copilot?

## References and links

[^1]: Bavarian, M., et al. (2022). [Efficient training of language models to fill in the middle](https://arxiv.org/abs/2207.14255). arXiv.

<!--Saving for reference-->
<!--
{{< collapse summary="Click collapse code block" openByDefault=false >}}

```bash
#!/usr/bin/env bash
some
bash
code
```

{{< /collapse >}}
-->
