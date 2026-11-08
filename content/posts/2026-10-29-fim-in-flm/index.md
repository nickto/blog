---
title: "Get inline suggestions from a model on AMD NPU"
date: 2026-10-29T12:30:49+02:00
draft: true
math: true
ShowToc: true
TocOpen: true
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
architecture, but rather a different training objective, where, given the text
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

where we first supply the prefix, or the part that goes before the completion, then
the suffix, or the part that goes after the completion, and ask the model to
fill in the middle, or the actual completion. So the full request looks like 
this

```json
{
  "model": "<model name>",
  "max_tokens": 64,
  "temperature": 0,
  "prompt": "<|fim_prefix|>def add(a, b):\n    <|fim_suffix|>\n    return c<|fim_middle|>"
}
```

and full `curl` command for the F16 Qwen 2.5 Coder 3B model, looks like this
(assuming that llama.cpp is running on `localhost:8080`):

```bash
curl -s http://localhost:8080/v1/completions \
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

We can discuss whether this is exactly what we wanted or not, but at least it is
hard to argue that this is not a perfectly valid completion.

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

Among many others, they ship:

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
was not there yet, but is there now.

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
the model itself was trained for FIM. Technically, one could maybe find a
workaround, but the existing tools expect the `/v1/completions` endpoint (or an even
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

Unfortunately, even though FLM offers quite a few models, none of them are
FIM capable. So we cannot use an off-the-shelf solution here.

## Converting model for NPU

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

### GGUF to Q4NX: the naive approach

[FLM Q4NX Converter](https://github.com/ROCm/FLM_Q4NX_Converter) expects a Q4_0
or Q4_1 quantized weights in GGUF format. And the [model's
card](https://fastflowlm.com/docs/models/qwen/#-model-card-qwen25-3b-instruct)
says that it uses the Q4_1 quantization, so we go to
[Hugging Face](https://huggingface.co/Qwen/Qwen2.5-Coder-3B), download the
weights, convert them to GGUF, quantize to Q4_1, and convert to Q4NX.

Sounds easy, does not work. The model produces garbage.

Let's look at our smoke test query.

```bash
curl -s http://localhost:52625/v1/completions \
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

Unlike the example we had before, where we might argue whether we wanted 
a completion of just one function, or a whole battery of them, here we have
a clear case of garbage.

### Q4_1 in, garbage out

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

- **Q4_0** stores one scale $d$ per group and reconstructs a weight as $d \times (q -
  8)$. The nibble is effectively signed: 8 (`1000`) means zero, values below it
  are negative, values above it are positive. (This is how GGUF stores it. When
  converting to Q4NX, the converter subtracts the 8 and stores true signed 4-bit
  numbers.)
- **Q4_1** stores an additional offset $m$ per group and reconstructs a weight
  as $d \times q + m$. The nibble is unsigned, and the offset $m$ shifts the whole
  group. Since the offset is a signed float, $q$ stays unsigned. When converting
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

Still not perfect (and we will get into this), but it looks like a step in the
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

## Improving the quality

So we got something that resembles the actual code, using the model converted
for FLM. However, there are two conspicuous issues. 

The first one is the special token leakage, i.e. `<|fim_middle|>`. Not only
special tokens should not be returned as plain text, but also the usage of this
token does not make sense: it is used to indicate the start of the middle
section, and it is what we end our prompt with.

But even if we strip this special token, there is still the second issue: the
completed code is actually bad:

```python
def add(a, b):
     a + b
    print(add(1, 2))
    return c
```

It got the indentation wrong, and even if we ignore the extra space, the
function will not work.

### Dealing with special tokens

There are five special tokens in the Qwen2.5-Coder tokenizer that matter for
FIM:

- `<|fim_prefix|>`: indicates the start of the text before the requested
  completion.
- `<|fim_middle|>`: indicates the start of the requested completion.
- `<|fim_suffix|>`: indicates the start of the text after the requested
  completion.
- `<|fim_pad|>`: a padding token used in training. It is not used at inference.
- `<|endoftext|>`: not FIM-specific, but in training it follows the middle
  section, so it should be the token that ends the requested completion.

FLM's official model is an Instruct one, so one more token is worth knowing
about:

- `<|im_end|>`: marks the end of a turn in the chat format. It is not used in
  FIM prompts.

By default, FLM's Instruct model stops only on `<|endoftext|>` and `<|im_end|>`
(and the HF base Coder checkpoint only on `<|endoftext|>`). But if any of the
FIM tokens appears in the output, the model has most likely gone astray, so the
inline completion should stop too.

There are also two other tokens, which make sense to add to our stop
token set:

- `<|repo_name|>`: indicates the start of the repository name, which opens a
  repository-level prompt.
- `<|file_sep|>`: separates files in a repository-level prompt. It is followed
  by the file path and then the file's content. If the model emits it, it is
  done with the current file, so the inline completion should stop.

So I patch `tokenizer_config.json` and `config.json` to stop on all these
tokens.

It does not solve the problem with the code generated being wrong, but lets us
quickly validate whether it solves the problem of leaking special tokens.

```bash
curl -s http://localhost:52625/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:3b-q4_0",
    "max_tokens": 64,
    "temperature": 0,
    "prompt": "<|fim_prefix|>def add(a, b):\n    <|fim_suffix|>\n    return c<|fim_middle|>"
  }' \
| jq '.choices[0]'
```

```json
{
  "text": " a + b\n    print(add(1, 2))",
  "index": 0,
  "logprobs": null,
  "finish_reason": "stop"
}
```

<details style="font-size: 0.8em; color: var(--secondary);">
  <summary>If you were reading carefully, ...</summary>
  ... you could have noticed that we used the <tt>-no-eos-fix</tt> suffix in the model
  names we tested before, which was a bit of a spoiler 😅
</details>

It stops the special tokens from leaking.

### Restoring precise embeddings

Fixing the stop tokens doesn't help with the second issue: the code itself is
still wrong. Given that the original F16 output on llama.cpp is fine, the
obvious suspect is quantization. And there is one easy tweak that we can try.

I quantize the whole GGUF to Q4_0 (`llama-quantize --pure`), so the embedding
table, which is just a lookup table of tokens to vectors, gets rounded to 4 bits
together with everything else. The Q4NX converter then dequantizes it and writes
it to the output file as an ordinary BF16 tensor. But because it dequantizes
from the 4-bit values, the result is no more precise than the 4-bit version:
only the format changes.

Yet the fact that Q4NX allows BF16 tensors at all lets us try a potential fix:
use the full-precision embedding table.

The obvious way to do it is to give the converter an F16 GGUF instead of the
Q4_0 one, but that does not work: it fails with `ValueError: not enough values
to unpack`. The converter cannot quantize F16 matrices itself.

But there is a hacky way around that. The Q4NX model file is a plain
[safetensors](https://huggingface.co/docs/safetensors) file, and it stores the
embedding as a full BF16 tensor, even though the rest of the model is only
4-bit. So we can simply replace the embedding tensor with the original one from
the HF checkpoint.

The new tensor has the same dtype and shape, and it is still just a lookup, so
the file size and the runtime cost stay the same. And FLM is happy with the
hack: it loads and serves the patched model without complaint. So there is
little reason not to do it.

There is one caveat, though. Qwen2.5-Coder-3B ties its input embedding to its
output layer (`lm_head`), which turns the model's final hidden state back into
token probabilities. In the Q4NX file, however, `lm_head` is a separate Q4_0
tensor built from the same weights, and it stays 4-bit. So only the input side
gets more precise.

Let's test the full-precision embeddings fix on our smoke-test prompt:

```bash
curl -s http://localhost:52625/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-coder:3b-q4_0-bf16emb",
    "max_tokens": 64,
    "temperature": 0,
    "prompt": "<|fim_prefix|>def add(a, b):\n    <|fim_suffix|>\n    return c<|fim_middle|>"
  }' \
| jq '.choices[0]'
```

It returns:

```json
{
  "text": "\n    return a + b",
  "index": 0,
  "logprobs": null,
  "finish_reason": "stop"
}
```

So the implied code is

```python
def add(a, b):
    
    return a + b
    return c
```

This code would actually work! The second return statement might attract a
linter complaint at most. But it is still not great: clearly not what we
wanted. So on its own, this tweak does not fully fix the bad completions. It is
still worth keeping, though, because there is little downside and it does not
conflict with the fix proposed in the next section. But whether the
full-precision embeddings add anything on top of it, we will see in the
[evaluation](#evaluation).

### Smarter quantization

With the special tokens and the embeddings sorted out, the completions were
still bad. And not only on our smoke-test prompt: on a larger (but still
ad-hoc) set of prompts, the model doubled tokens (`ret ret`), dropped
them, threw in stray Cyrillic, or returned nothing at all.

Was it FLM's fault? Partly. The same Q4_0 GGUF in llama.cpp did much better, yet
it still showed milder versions of the same flaws. So FLM made things worse, but
the root of the problem seemed to be somewhere else.

Since llama.cpp suffered from the same flaws, the problem had to be in the model
file itself, so the quantization was the main suspect. But FLM's official
Qwen2.5-3B-Instruct is also Q4_0, and it works fine. 

{{< collapse summary="So what does the official model do differently?" openByDefault=false >}}

FLM does not ship an official Coder model to compare against. So I ran my
pipeline on Qwen2.5-3B-Instruct instead and compared the result with the
official Q4NX file. The idea was to double-check my conversion: is my pipeline
producing the same quantized weights given the same full-precision input? I
expected them to be bit-dentical: after all, FLM does not openly claim to do any
additional fine-tuning or other optimisation. But the weights were different.
Only about a quarter of the tensors (109 of 435: the embedding, the final norm,
and almost all of the biases) were bit-identical. 

{{< /collapse >}}

So, it turns out that the weight matrices differed and they did so in a very particular way.

To explain how, we need to talk about [AWQ: Activation-aware Weight
Quantization](https://arxiv.org/abs/2306.00978) (Lin, J., et al., 2023). 

#### Scrutinizing Q4_0 errors

In order to understand it, let's recap how Q4_0 works, and where the rounding
errors come from. 

Q4_0 splits the weights into small groups (groups of 32 weights to be precise,
but it is not important for us). Each group gets one scale $d$, in order to fit
the range of the original floating point values into the −8 to +7 range of
4-bit integers. This can be described more formally as $d = \max |w| \div 8$.

Thus, every weight is rounded to the nearest multiple of $d$, so it is off by at
most $d \div 2$, no matter how large or small the weight is.

Let's have a look at the example. Here is a toy group of four weights. The
largest one is −0.80, so $d = 0.80 \div 8 = 0.1$, and $d \div 2 = 0.05$:

|   $w$ | $w \div d$ | Integer | Rounded $w$ | Rounding error |
| ----: | ---------: | ------: | ----------: | -------------: |
| −0.80 |       −8.0 |      −8 |       −0.80 |     0.00       |
|  0.14 |        1.4 |       1 |        0.10 |     0.04 ≤ 0.05|
| −0.50 |       −5.0 |      −5 |       −0.50 |     0.00       |
|  0.33 |        3.3 |       3 |        0.30 |     0.03 ≤ 0.05|

Only the integers are stored, plus one $d$ per group.

What we care about, though, is not the rounding error of the weights
themselves, but the error they produce in the layer's output. Let's have a look at a single layer example:
`$$y = \sigma(W x) = \sigma(h),$$`
where 

- $W$ is an $m \times n$ weight matrix, 
- $x$ is the $n \times 1$ input vector, 
- $h = W x$ is the $m \times 1$ output of the linear part, before the
  non-linearity is applied,
- $\sigma$ is a non-linear activation function,
- and $y$ is the $m \times 1$ output. 

(Except for the first layer) the input is also an output, but that of the
previous linear layer after the non-linear activation function is applied. That
is why the input of a layer is called an _activation_ (not to be confused with
the activation function `$\sigma$`: the activation is what comes out of it).

Another important term that we will use is a _channel_. The term comes from
images, where each pixel has a red, a green and a blue channel. Neural networks
kept the term for the separate features at each position, and in a linear
layer, each input feature $x_i$ is its own channel. Consider the following
example:
`$$
y = \sigma \left( W \cdot x \right) =
\begin{bmatrix}
  y_1 \\
  y_2 \\
  y_3
\end{bmatrix} =
\sigma \left(
\begin{bmatrix}
  w_{11} & w_{12} & w_{13} \\
  w_{21} & w_{22} & w_{23} \\
  w_{31} & w_{32} & w_{33}
\end{bmatrix}
\begin{bmatrix}
  x_1 \\
  x_2 \\
  x_3
\end{bmatrix} \right) = 
\sigma \left(
\begin{bmatrix}
  \mathbf{w_{11} x_1} + w_{12} x_2 + w_{13} x_3 \\
  \mathbf{w_{21} x_1} + w_{22} x_2 + w_{23} x_3 \\
  \mathbf{w_{31} x_1} + w_{32} x_2 + w_{33} x_3
\end{bmatrix}
\right)
$$`
Notice how the activation `$x_1$` contributes to the output only via column 1 of
the matrix $W$. So each channel has its own column of weights, and whatever
happens to channel $i$---both `$x_i$` and its column---affects every output. Also notice the contrary: each output is a sum with one term from every channel.

#### Not all channels are born equal

Quantization groups run along the rows, so each weight in a group belongs to a
different channel. And not all channels are equally important
for the output. We have already shown that weights have rounding errors, but
their errors are all within $d \div 2$ in a group. What makes them drastically
unequal are the activations they are applied to. To illustrate this, let's
extend our numerical example above with activations $x$.

| Channel |     $w$ |  $x$ | Rounded $w$ | Rounding error | Error ($x \times$ rounding error) |
| ------: | ----: | -: | --------: | ----: | --------: |
|       1 | −0.80 | 0.1 |     −0.80 |  0.00 |      0.00 |
|       2 |  0.14 | 10 |      0.10 |  0.04 |  **0.40** |
|       3 | −0.50 |  1 |     −0.50 |  0.00 |      0.00 |
|       4 |  0.33 |  1 |      0.30 |  0.03 |      0.03 |
|   Total |       |    |           |       |  **0.43** |

The rounding errors of channels 2 and 4 are about the same, but channel 2
contributes almost all of the output error. So some channels are clearly more
important for the output and we want to focus on retaining their precision, even at
the expense of other, less important channels. AWQ exploits this in two ways:
scaling and clipping: the former improves precision by focusing on channels with
large activations, and the latter gives up precision in low activation channels
in order to improve it in the rest.

#### Scaling: make activations smaller

If the activation is large, the contribution of this channel to the output error
is also large (channel 2 in our example). So AWQ shrinks large activations,
which decreases the total output error.

Why does this work? Let's look at the error of output $j$ before the
non-linearity $\sigma$ is applied:
`$$
\epsilon_j = \hat{h}_j - h_j = \sum_i \hat{w}_{ji} x_i - \sum_i w_{ji} x_i =
\sum_i (\hat{w}_{ji} - w_{ji}) x_i,
$$`
where `$\hat{w}_{ji}$` is the rounded weight. So every channel $i$ adds its
activation times the rounding error of its weight. The rounding error
`$\hat{w}_{ji} - w_{ji}$` is at most $d \div 2$, no matter what the weight is,
so
`$$
|\epsilon_j| \le \frac{d}{2} \sum_i |x_i|.
$$`
<details style="font-size: 0.8em; color: var(--secondary); margin-top: -4rem;">
  <summary>Strictly speaking, ...</summary>
  ... $d$ is different for each group of weights, but this does not change the intuition.
</details>
<br/>

So the only knob we can tweak in order to reduce `$|\epsilon_j|$` is to make the
activations `$x_i$` smaller.

Of course, we cannot just shrink an activation: the layer would then compute
something else. So we divide the activation by a scaling factor $s$, and
multiply the corresponding column of weights by the same $s$. Then every term
`$w_{ji} x_i$` of `$h_j$` stays the same:
`$$
(s \cdot w_{ji}) \cdot \left(x_i \cdot \frac{1}{s}\right) = w_{ji} x_i.
$$`
Since $h$ stays the same, $y$ also stays exactly the same. Scaling the weight up
does not make its rounding error larger either: the bound of $d \div 2$ does not
depend on the weight, only on $d$. Unless the scaled weight becomes the largest
weight in the group, and we need to pick a new $d$: this is the limit of how
much we can scale without giving up anything else.

Back to our example. With $s = 4$ for channel 2, its weight becomes
$0.14 \times 4 = 0.56$ and its activation $10 \div 4 = 2.5$. The largest weight
is still −0.80, so $d$ is still 0.1:

| Channel |   $w$ | $x$ | Rounded $w$ | Rounding error | Error ($x \times$ rounding error) |
| ------: | ----: | --: | ----------: | -------------: | --------------------------------: |
|       1 | −0.80 | 0.1 |       −0.80 |           0.00 |                              0.00 |
|       2 |  0.56 | 2.5 |        0.60 |           0.04 |                          **0.10** |
|       3 | −0.50 |   1 |       −0.50 |           0.00 |                              0.00 |
|       4 |  0.33 |   1 |        0.30 |           0.03 |                              0.03 |
|   Total |       |     |             |                |                          **0.13** |

The rounding error of channel 2 is still 0.04, but it is now multiplied by 2.5
instead of 10. So the contribution of channel 2 dropped four times, from 0.40 to
0.10, and the total error dropped from 0.43 to 0.13.

So why not take a huge $s$? Because at some point the scaled weight becomes the
largest in its group, so we need to pick a larger $d$, which decreases
the precision for the rest of the group. And remember that $s$ applies to the
whole column, which crosses many groups, so the same $s$ has to work for all of
them. Too little scaling does not help, too much hurts, so the right $s$ has to
be found by a search.

But how do we know which activations are large? Unlike the weights, they are
not part of the model: they depend on the data. AWQ solves this with
_calibration_: it runs the model on some representative sample and records
the activations of each layer. The average magnitude of each channel tells it
which channels are important.

AWQ then scales the channels with larger average activations more. How much
more is found by a search, layer by layer: AWQ tries several sets of scales,
quantizes the scaled weights for each, runs the calibration activations through
the layer, and keeps the set whose $h$ is closest to the original.

{{< collapse summary="And the division by $s$ comes for free at inference time." openByDefault=false >}}

This does not work in _every_ neural network, but it does in most LLMs.
For instance, in our toy example this wouldn't work, because we feed the 
ouput of non-linearity, $\sigma(Wx)$, directly as activation into the next layer.

But in most transformers, the attention and MLP blocks start with some kind  
of layer normalization. In Qwen2.5's case, for example, it's RMSNorm, which  
multiplies each channel by its own learned weight. For the linear layers  
right after it, we divide that weight by $s$. For other linear layers there are  
similar tricks.

This highlights, however, that AWQ cannot treat the model as a black box: 
the architecture drives the decision on where to fold the scales, and 
whether the folding is possible at all.

{{< /collapse >}}

#### Clipping: do not let outliers set the range

Scaling tackled the activations in our error bound:
`$$
|\epsilon_j| \le \frac{d}{2} \sum_i |x_i|.
$$`
Clipping tackles the other term: $d$.

Remember that $d$ is set by the largest weight in the group. So a single outlier
forces a coarse grid on all the weights in the group. That is fine if the
outlier belongs to an important channel. But if its activation is small, we waste
the precision of the whole group on a weight whose error barely matters.

Clipping sets the ceiling on the magnitude of weights in our group below the
current largest value. So the outliers above this cap get a worse error than
before the clipping. It sounds bad, but could actually be fine, if the channels to
which these outliers belong were not important. At the same time, we can now
decrease $d$, thus making the grid finer, which on average should improve the 
errors of the rest of the weights in the group.

Thus, we trade the error of insignificant outliers for better precision of 
important channels. If the total error decreases, we gain precision. 

Back to our toy example before scaling. Channel 1 has the largest weight,
−0.80, but its activation is only 0.1. Let's cap the group at 0.64, so
$d$ becomes  $0.64 \div 8 = 0.08$ and $d \div 2 = 0.04$, down from 0.05:

| Channel |   $w$ | $x$ | Clipped $w$ | Rounded $w$ | Rounding error | Error ($x \times$ rounding error) |
| ------: | ----: | --: | ----------: | ----------: | -------------: | --------------------------------: |
|       1 | −0.80 | 0.1 |       −0.64 |       −0.64 |           0.16 |                              0.02 |
|       2 |  0.14 |  10 |        0.14 |        0.16 |           0.02 |                          **0.20** |
|       3 | −0.50 |   1 |       −0.50 |       −0.48 |           0.02 |                              0.02 |
|       4 |  0.33 |   1 |        0.33 |        0.32 |           0.01 |                              0.01 |
|   Total |       |     |             |             |                |                          **0.25** |

Channel 1 is now off by 0.16, which sounds like huge rounding error. And it is,
but only for the weight itself, which we ultimately don't care about. And
multiplied by an activation of 0.1, the contribution of this channel in the
output error shrinks to 0.02. Meanwhile, the finer grid halves the error of the
important channel 2, and the total drops from 0.43 to 0.25.

So why not clip harder? Because the deeper we cut, the larger the error of the
outlier, and at some point the cap starts cutting into weights that do matter.
Cap the group at 0.32, for example, and channels 3 and 4 get clipped too: the
total error climbs back to 0.44, worse than no clipping at all.

Just like with scaling, the right cap depends on the activations, so AWQ finds
it with the calibration data. For each group, it tries a range of caps and keeps
the one with the smallest output error. This happens after scaling, on the
already scaled weights, so the two methods can be combined: scaling protects the
important channels, and clipping prevents the unimportant ones from driving $d$.

Compared to scaling, there is one important aspect that we should be aware
though. Scaling does not change what the layer computes, while clipping does:
there is no analogue of the invers scale for clipping. But given that we are
already heavily quantizing the model, the weights are goind to suffer anyway.
Clipping just helps controls where the error goes.

Importantly, all of this happens in full prevision _before_ quantization. The
result is a normal checkpoint with the exact same architecture, computes almost
the same values (only clipping changes it a bit). It's just that these
tranfsormations help decreasing the rounding errors in the subsequent 4-bit
quantization. 

We can then quantize it with plain Q4_0, as before. Since `llama-quantize` picks
the step from the largest weight in each group, it automatically picks up the
clipped values. And this is exactly the fingerprint my LLM detective found in
the official model:

- Some weight columns are multiplied by a scale $s$, and the layers right
  before them are adjusted to divide the matching activations by the same $s$,
  just like in the scaling trick above.
- There is one place where AWQ could fold a scale, but
  [AutoAWQ](https://github.com/casper-hansen/AutoAWQ), the popular AWQ
  implementation, does not do it for models like Qwen2.5. The official model is
  not scaled there either, which points to AutoAWQ specifically, not just to AWQ
  in general.
- In some layers, about 30% of the groups are clipped, while in others there is
  no clipping at all. The unclipped layers are the ones AutoAWQ deliberately
  leaves alone, because errors there distort attention.

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
