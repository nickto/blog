---
layout: post
disqus: true
title:  "Table and figure captions in R Markdown"
date:   2017-02-03 16:30:00
categories: [R Markdown]
tags: [r, r markdown, captions, figures, tables]
---
[R Markdown](http://rmarkdown.rstudio.com/) is a useful tool for producing reports using R. The problem is that decent quality reports require captions for figures and tables, and it is not straightforward to make them with R Markdown. Yet, it is still quite easy.

## Pandoc's Markdown: numbered captions
They key to adding captions is that [knitr](https://cran.r-project.org/web/packages/knitr/index.html) converts an `.Rmd` file to an `.md` file first, and then uses [pandoc](http://pandoc.org/) to convert it to html, pdf or another format. Therefore, everything that works in Pandoc also works in R Markdown. There multiple flavours of Markdown. Pandoc uses its own version called [Pandoc's Markdown](http://pandoc.org/MANUAL.html#pandocs-markdown). Among other things it allows captioning your figures and tables.

Figure captions can be produced in the following way:

{% highlight markdown %}
![Example of an image with a caption.](https://www.r-project.org/logo/Rlogo.png)
{% endhighlight %}

And table captions are produced like this:

{% highlight markdown %}
| Column heading 1 | Column heading 2 |
| -----------------| -----------------|
| Some value       | Another value    |
| One more value   | And the last one |

Table: Example of a table with a caption.
{% endhighlight %}

If you want you result in a PDF format, then the default Pandoc settings would render image caption below an image, tables captions above a table. Moreover, it would automatically number it. Note, however, that this is not the case for other formats and, therefore, in this post I will focus only on PDF output.

## LaTeX: cross-references
Adjusting the example above, it would look like this (in this example we have also changed the size of an image by adding `{width=250px}`):
{% highlight markdown %}
![Example of an image with a caption. \label{fig:example-figure}](https://www.r-project.org/logo/Rlogo.png){width=250px}

And in the text we can refer to Figure \ref{fig:example-figure} and Table \ref{tab:example-table} both before and after it appeared.

| Column heading 1 | Column heading 2 |
| -----------------| -----------------|
| Some value       | Another values   |
| One more values  | And the last one |

Table: Example of a table with a caption. Note, that there is an empty line before this caption. \label{tab:example-table}
{% endhighlight %}

[This](/assets/posts/2016-11-10-rmarkdown-captions/pandoc-example.pdf) is how it looks after compiling it into PDF (in the command line: `pandoc pandoc-example.md -o pandoc-example.pdf`, where `pandoc-example.md` is our Markdown input, and we want a PDF output):

<img src="/assets/posts/2016-11-10-rmarkdown-captions/pandoc-example-screenshot.png" style="width: 90%; display: block; margin-left: auto; margin-right: auto;">


## R Markdown: combining both
If you are just adding images from a source file and manual tables to you R Markdown file, then the syntax above should work just fine. However, what should we do if we generate the images and tables dynamically?

### Tables
Let us start with tables, because it is a little bit easier. If you want a beautiful nicely-formatted table, you can use `knitr::kable` function (I guess it stands for "knitr table", rather than "cable"). For example:


{% highlight markdown %}
```{r}
data(iris)
knitr::kable(head(iris))
```

Table: Head of iris data. \label{tab:iris}

And we can refer Table \ref{tab:iris} just as in Pandoc Markdown.
{% endhighlight %}


### Images
Images are a little bit trickier. We cannot just use the Pandoc approach, because we use a completely different syntax, when we generate figures dynamically. Luckily, R Markdown has a built-in way of adding captions.

In order to do that, we need to add the following lines to our heading (frontmatter): the text between `---` and `---` at the very top of the document, which allows specifying LaTeX figure captions:

{% highlight markdown %}
---
output:
  pdf_document:
    fig_caption: yes
---
{% endhighlight %}

And now we can add captions to the code chunks with a `fig.cap` option. Like this:

{% highlight markdown %}
```{r, fig.cap="Scatterplot of width and length. \\label{fig:iris}"}
plot(iris$Sepal.Length, iris$Sepal.Width)
```

And we can refer Figure \ref{fig:iris} just as in Pandoc Markdown.
{% endhighlight %}

Note the double backslash, it is needed because in R strings it serves an [escape character](https://en.wikipedia.org/wiki/Escape_character), and to make and actual backslash we need to escape it with a backslash first, which, obviously, results in a double backslash.

### Result
Combining the table and the figure examples, we get the something like [this](/assets/posts/2016-11-10-rmarkdown-captions/rmarkdown-example.pdf):

<img src="/assets/posts/2016-11-10-rmarkdown-captions/rmarkdown-example-screenshot.png" style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

A reproducible example of the image above can be found [here](/assets/posts/2016-11-10-rmarkdown-captions/rmarkdown-example.Rmd).
