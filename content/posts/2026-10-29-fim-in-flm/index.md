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
different training objective. Technically, most LLMs should be able to do the
task if we describe what we expect from them in the prompt. But this is very
chatty, less efficient, and more likely to produce an output format we do not
expect.

However, making a model capable of doing FIM tasks requires a change in the
training pipeline, and not all models were trained with this change. So we need
to narrow down the list of models to the ones that were.

Given the aspects which I will discuss in the NPU section, I will just mention
that [Qwen2.5-Coder-3B](https://huggingface.co/Qwen/Qwen2.5-Coder-3B) is one of
these models.




## GPU

> infilling, where the model is tasked with generating text at a specific location within a prompt, while conditioning on both a prefix and a suffix


Running on GPU is straightforward: just find a suitable model and serve with [llama.cpp](https://github.com/ggml-org/llama.cpp).

The only tricky part is "what's a suitable model?"

## NPU

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
