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

Models used for this type of task are trained with the _fill-in-the-middle_
(FIM) objective[^1]. This is not a different model architecture, but rather a
different training objective, where given the text before and after the missing
part, the model should fill in the missing part. 

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

### FLM

- What FLM is and why it is the easiest way onto this NPU
- What you get out of the box: the model list and how to serve one
- `/completion` vs `/chat/completions`, and why FIM needs the raw prompt

### The catch: no coder model

- The model choice is limited, and none of the models is a coder model
- `/completion` support alone is not enough: the model must be trained for FIM
- Why I picked Qwen2.5-Coder-3B (pays off the promise in the FIM section)

## Converting the model

### From GGUF to NPU2

- The semi-official conversion scripts: what they do
- Why they did not work for Qwen
- The matrix reordering

### It runs, but the output is bad

- A real example of a bad completion
- What I think causes it

### Improving the quality

- What I tried, briefly, and why each attempt fell short
- Why I settled on AWQ

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
