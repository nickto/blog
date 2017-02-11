---
layout: post
comments: true
use_math: true
title:  "Acceptance-rejection method for generating random variables"
date:   2017-02-10 21:40:00
categories: [statistics]
tags: [statistics, distributions]
---

[Acceptance-rejection method](https://en.wikipedia.org/wiki/Rejection_sampling) is a method for generating samples from a distribution, for which the probability density function is known, but inverse cumulative probability function is not known, and thus, using the [inverse CDF method](https://en.wikipedia.org/wiki/Inverse_transform_sampling) is not possible.

Although there is quite a lot of information on the topic available, I will try to explain the method the way that I (a.k.a 5-year-old) understand.

## Idea

### Majorizing distribution
Let us say that we want to draw numbers from some distribution $ f(x) $---_target distribution_---but we have only distribution $ g(x) $, such that by multiplying it with some constant $ c $ it will always be larger than $ f(x) $,

$$
\forall x: cg(x) \ge f(x),
$$

then $ c g(x)$ is _majorizing distribution_.

<img src="/assets/posts/2017-02-10-acceptance-rejection/example_1_edited.svg" alt="Distributions." style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

What if we don't have such $ g(x)$? That is impossible. We always have it: if nothing else works, we can rescale the uniform distribution by the appropriate constant, $ c $, such that $ c g(x)  $ is equal (or larger) than $ f(x) $ in the mode. Like this:

<img src="/assets/posts/2017-02-10-acceptance-rejection/example_2_edited.svg" alt="Uniform as majorizing." style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

However, to make intuition more illustrative, let us continue using the previous example. Moreover, using the uniform distribution as the majorizing one can be extremely inefficient, and we will later see why.

### Draw a number
After we have found appropriate majorizing distribution, we draw a number, $ y $ from $ g(x) $, using any other method. We will draw numbers from regions with high $ g(x) $ density more often (that is, basically, the definition of density). Thus, if $ g(x) $ is similar to $ f(x) $ then we already get some approximation.

So, let us say that the value of $ y $ appeared to be the following[^1]:

<img src="/assets/posts/2017-02-10-acceptance-rejection/example_3_edited.svg" alt="Realizations." style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

### Decide whether to accept or reject it
If we wanted to draw realizations from the $ g(x) $ distribution, we would stop here. However, we want to draw them from another---$f(x)$---distribution. Thus, we have to adjust for it. We know that the actual probability of drawing this number was higher (because $ cg(y) \ge f(x)$), therefore, we want to sometimes discard this number and pretend that nothing happened. In this way, we will actually lower the probability of returning this number as the realization of the random variable.

Therefore, we keep this number and claim that this actually is the realization from the target distribution only in

$$
\frac{f(y)}{cg(y)}
$$
proportion of cases: there was $ cg(y) $ probability[^2] to draw this number, but we wanted it to draw only with probability $ f(y) $. This makes much more sense when we visualize it:

<img src="/assets/posts/2017-02-10-acceptance-rejection/example_4_edited.svg" alt="Why this fraction?" style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

Note that because we have chosen the majorizing distribution to be greater or equal to the target one, the described fraction will be always between 0 and 1:

$$
\frac{f(y)}{cg(y)} \in (0;1) .
$$

Thus, in order to ensure that we keep it only in the required proportion of cases we will draw another random variable, $ u $, from a uniform distribution,

$$
u \sim \operatorname{unif}(0;1) ,
$$

and accept $ y $ as a realization from $ f(x) $ only if

$$
u \le \frac{f(y)}{cg(y)} ,
$$

otherwise reject it.

Let us visualize it. Let us consider 3 different values of $ u $:

<img src="/assets/posts/2017-02-10-acceptance-rejection/example_5_edited.svg" alt="Accepting and rejecting." style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

For values $ u_2 $ and $ u_3 $ we reject $ y $ and for the value $ u_1 $)---accept it. All values of $ u_i $ are equally likely to appear. Moreover, the value $ u $ is equally likely to appear anywhere on the line (because it is sampled from the uniform distribution). Therefore, we will accept it in the required proportion of cases.

## Algorithm
Now it is easy to put this algorithm in pseudo-code:

$$
\begin{align*}
1.&\; \mbox{Generate $y \sim g(x)$} \\
2.&\; \mbox{Generate $u \sim \operatorname{unif}(0;1)$} \\
3.&\; \mbox{if}\; u \le \frac{f(y)}{cg(y)}\; \mbox{then} \\
&\; \quad 3.a. \; x = y \\
&\; \mbox{else} \\
&\; \quad 3.b.\; \mbox{go to 1.}
\end{align*}
$$

## Proof[^3]
First, let us find the expected number of draws, $ N$ before we finally get a success. It is easy to see that this quantity is [geometrically distributed](https://en.wikipedia.org/wiki/Geometric_distribution), because that is what the geometric distribution models.

$$
\begin{align}
\Pr(N = n) = &\ (1 - p)^{n - 1} p, \quad n \ge 1, \, \operatorname{E}(N) = &\ \frac{1}{p} ,
\end{align}
$$

where $ p $ is probability of success on a given trial.

Second, let us find the value of $ p $:

$$
\begin{align}
p = \Pr \left( U \le \frac{f(Y)}{cg(Y)} \right) .
\end{align}
$$

Since $ \frac{f(Y)}{cg(Y)} $ is a random variable itself, let us fix the value of $ Y $ to $ y $ and find $ p \mid Y = y $

$$
\begin{align}
p = &\ \Pr \left( U \le \frac{f(Y)}{cg(Y)} \mid Y = y \right) \\
  = &\ \Pr \left( U \le \frac{f(y)}{cg(y)} \right) ,
\end{align}
$$

which simplifies, because $U \sim \operatorname{unif}(0;1)$ we simply integrate $1$

$$
\begin{align}
p = &\ \int_{0}^{\frac{f(y)}{cg(y)}} 1 dt \\
  = &\ \frac{f(y)}{cg(y)} .
\end{align}
$$

Then we remove the conditioning by integrating over all possible values of $y$

$$
\begin{align}
p = & \int_{-\infty}^{+\infty} \frac{f(y)}{cg(y)} \times g(y) dy
  = \frac{1}{c} \frac{1}{c} \int_{-\infty}^{+\infty} \frac{f(y)}{c} \frac{g(y)}{g(y)} dy \\
  = &\ \frac{1}{c} \underbrace{\int_{-\infty}^{+\infty} f(y) dy }_{1} = \frac{1}{c} \times 1 = \frac{1}{c} \label{eq:t} ,
\end{align}
$$

where the integral in (\ref{eq:t}) is equal to $1$, because $f(y)$ is a popper density function and integrates to $1$.





## Notes
[^1]: Since $cg(x)$ is just a scaled version of $g(x)$, we will not show it anymore.
[^2]: Technically, this is not probability, because we are talking about continuous distributions, but this should be close enough for intuition.
[^3]: Proof is taken from [here](http://www.columbia.edu/~ks20/4703-Sigman/4703-07-Notes-ARM.pdf) with some comments.
