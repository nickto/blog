---
layout: post
comments: true
title:  "LaTeX fonts in R Markdown plots"
date:   2017-02-03 20:30:00
categories: [R Markdown]
tags: [r, r markdown, figures, latex, fonts]
---

## TL; DR

Make sure you have [tikzDevice](https://cran.r-project.org/web/packages/tikzDevice/index.html) package, then either specify `dev = "tikz"` option for all chunks like this

{% highlight r %}
knitr::opts_chunk$set(..., dev = "tikz")
{% endhighlight %}

or specify it for each chunk separately.

## Longer story

Let us be honest, one of the reasons we use [R Markdown](http://rmarkdown.rstudio.com/) to compile documents into PDF is the aesthetic pleasure provided by LaTeX. However, all the efforts can be ruined by wrong fonts in plots that are not the same as in the rest of the document. [For example](/assets/posts/2017-02-03-rmarkdown-plot-fonts/poor-fonts.pdf),

![These are some ugly fonts!]({{ site.url }}/assets/posts/2017-02-03-rmarkdown-plot-fonts/poor-fonts-screenshot.png)

Well, these are some ugly fonts (not by itself, but in combination with the rest of the document). Would not it be much better to have something like [this](/assets/posts/2017-02-03-rmarkdown-plot-fonts/good-fonts.pdf)?

![These are some nice fonts!]({{ site.url }}/assets/posts/2017-02-03-rmarkdown-plot-fonts/good-fonts-screenshot.png)

So how can we make the good ones? Well, the answer is easy: just let LaTeX render your images and it will take care of the rest.

Why LaTeX? In short, because it is a LaTeX engine that compiles a PDF. Remember that for producing a PDF, `knitr` converts R Markdown to Pandoc Markdown, which converts it to LaTeX, which and compiles it into PDF using a specified engine. If you have not changed it, then it's probably _pdflatex_, but that is not important in absolute majority of cases.

Whenever we render a picture, for example a plot, using either the base `plot` function or `ggplot`, we send it to a printing device. When it appears somewhere in RStudio (highly likely that it appears in the bottom right corner), it means that it was printed to the `RStudioGD` device. When we save it to a file, we print it to, for example, a `png` or `pdf` device. And if we want to save it in a format that is understood by LaTeX, we print with the device that produces the desired output. Pictures in (La)TeX are compiled from [TikZ](https://en.wikipedia.org/wiki/PGF/TikZ) code. Thus, we need to print our pictures to a `tikz` device. Luckily, someone (or rather Kirill Müller) was kind enough to write a package that adds `tikz` device via [tikzDevice](https://cran.r-project.org/web/packages/tikzDevice/index.html) package, which is availble on [CRAN](https://cran.r-project.org/).

One might wonder: "But we do not specify a printing device when use R Markdown!" This is partially true. If we do not specify a device in an R script, it will attempt to print to the current active device, which is highly likely to be `RStudioGD`. If we do not specify it in R Markdown, it will attempt to print to its default device. There is an option for chunks, however, that allows specifying the `dev` option, which stands for "device". We can either set it equal to `"tikz"` for all chunks by adding this option to the `opts_chunk`

{% highlight r %}
knitr::opts_chunk$set(..., dev = "tikz")
{% endhighlight %}

or specify it for each chunk manually, like this

{% highlight markdown %}
```{r, dev = "tikz"}
# Some plotting code goes here, e.g.
plot(rnorm(10), rnorm(10))
```
{% endhighlight %}

## Reproducible example
Reproducible example can be found [here](/assets/posts/2017-02-03-rmarkdown-plot-fonts/good-fonts.Rmd).
