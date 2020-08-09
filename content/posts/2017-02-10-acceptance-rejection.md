---
title:  "Acceptance-rejection method for generating random variables"
date:   2017-02-10T20:40:00+02:00
draft: false
staticPath: /posts/2017-02-10-acceptance-rejection
---

[Acceptance-rejection method](https://en.wikipedia.org/wiki/Rejection_sampling)
is a method for generating samples from a distribution, for which the
probability density function is known, but inverse cumulative probability
function is not known, and thus, using the
[inverse CDF method](https://en.wikipedia.org/wiki/Inverse_transform_sampling)
is not possible.

Although there is quite a lot of information on the topic available, I will try
to explain the method the way that I (a.k.a 5-year-old) understand.

## Idea

### Majorizing distribution

Let us say that we want to draw numbers from some distribution[^1] $ f(x)
$---*target distribution*---but we have only distribution $ g(x) $, such that by
multiplying it with some constant $ c $ it is always larger than $ f(x) $,

`$$
\forall x: cg(x) \ge f(x),
$$`

then $ c g(x)$ is called the _majorizing distribution_.

<img src="{{< static_path >}}/example_1_edited.svg" alt="Distributions."
style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

### Draw a number

After we have found an appropriate majorizing distribution, we draw a number, $
y $ from $ g(x) $, using any other method (e.g., inverse CDF). We draw numbers
from regions with high $ g(x) $ density more often (that is, basically, the
definition of density). Thus, if $ g(x) $ is similar to $ f(x) $ then we already
get some approximation.

So, let us say that the value of $ y $ appeared to be the following[^2]:

<img src="{{< static_path >}}/example_3_edited.svg" alt="Realizations."
style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

### Decide whether to accept or reject it

If we wanted to draw realizations from the $ g(x) $ distribution, we would stop
here. However, we want to draw them from another---$f(x)$---distribution. Thus,
we have to adjust for it. We know that the actual probability of drawing this
number is higher (because $ cg(y) \ge f(x)$), therefore, we want to sometimes
discard this number and pretend that nothing happened. In this way, we actually
lower the probability of returning this number as the realization of the random
variable.

Therefore, we keep this number and claim that this actually is the realization
from the target distribution only in

`$$
\frac{f(y)}{cg(y)}
$$`

proportion of cases: there is $ cg(y) $ probability[^3] to draw this number, but
we wanted it to draw only with probability $ f(y) $. This makes much more sense
when we visualize it:

<img src="{{< static_path >}}/example_4_edited.svg" alt="Why this fraction?"
style="width: 100%; display: block; margin-left: auto; margin-right: auto;">

Note that because we have chosen the majorizing distribution to be greater or
equal to the target one, the described fraction is always between 0 and 1:

`$$
\frac{f(y)}{cg(y)} \in (0;1) .
$$`

Thus, in order to ensure that we keep it only in the required proportion of
cases we draw another random variable, $ u $, from a uniform distribution,

`$$
u \sim \operatorname{unif}(0;1) ,
$$`

and accept $ y $ as a realization from $ f(x) $ only if

`$$
u \le \frac{f(y)}{cg(y)} ,
$$`

otherwise reject it.

Let us visualize it. Let us consider 3 possible values of $ u $:

<img src="{{< static_path >}}/example_5_edited.svg" alt="Accepting and
rejecting." style="width: 100%; display: block; margin-left: auto; margin-right:
auto;">

For values $ u_2 $ and $ u_3 $ we would reject $ y $ and for the value $ u_1
$)---accept it. All values of $ u_i $ are equally likely to appear. Moreover,
the value $ u $ is equally likely to appear anywhere on the line (because it is
sampled from the uniform distribution). Therefore, we accept $y$ in the required
proportion of cases.

To sum up, we draw realizations from $cg(y)$ distribution but accept only a
fraction of them in order to correct for differences between $cg(y)$ and $f(y)$.

## Algorithm

Now it is easy to put this algorithm into pseudo-code:


`$$
\begin{align*}
1.&\; \mbox{Generate $y \sim g(x)$} \\
2.&\; \mbox{Generate $u \sim \operatorname{unif}(0;1)$} \\
3.&\; \mbox{if}\; u \le \frac{f(y)}{cg(y)}\; \mbox{then} \\
&\; \quad 3.a. \; x = y \\
&\; \mbox{else} \\
&\; \quad 3.b.\; \mbox{go to 1.}
\end{align*}
$$`


## Proof[^4]

First, let us find the expected number of draws, $N$, before we finally get a
success. It is easy to see that this quantity is
[geometrically distributed](https://en.wikipedia.org/wiki/Geometric_distribution),
because that is what the geometric distribution models.

`$$
\begin{align}
\Pr(N = n) = &\ (1 - p)^{n - 1} p, \quad n \ge 1, \, \operatorname{E}(N) = \frac{1}{p} ,
\end{align}
$$`

where $ p $ is probability of success on a given trial.

Second, let us find the value of $ p $:

`$$
\begin{align}
p = \Pr \left( U \le \frac{f(Y)}{cg(Y)} \right) \label{eq:p} .
\end{align}
$$`

Since $ \frac{f(Y)}{cg(Y)} $ is a random variable itself, let us fix the value
of $ Y $ to $ y $ and find $ p \mid Y = y $

`$$
\begin{align}
p = &\ \Pr \left( U \le \frac{f(Y)}{cg(Y)} \mid Y = y \right) \label{eq:U_cond_on_y_equality} \\
  = &\ \Pr \left( U \le \frac{f(y)}{cg(y)} \right) ,
\end{align}
$$`

which can be simplified: since $U \sim \operatorname{unif}(0;1)$, we simply
integrate $1$, because because the value of $\operatorname{unif}(0;1)$ density
function is always 1 on this interval:

`$$
\begin{align}
p = &\ \int_{0}^{\frac{f(y)}{cg(y)}} 1 dt \\
  = &\ \frac{f(y)}{cg(y)} .
\end{align}
$$`

Then we remove the conditioning by integrating over all possible values of $y$

$$
\begin{align}
p = & \int_{-\infty}^{+\infty} \frac{f(y)}{cg(y)} \times g(y) dy
  = \frac{1}{c} \int_{-\infty}^{+\infty} f(y) \frac{g(y)}{g(y)} dy \\\\
  = &\ \frac{1}{c} \underbrace{\int_{-\infty}^{+\infty} f(y) dy }_{1} = \frac{1}{c} \times 1 = \frac{1}{c} \label{eq:t} ,
\end{align}
$$

where the integral in (\ref{eq:t}) is equal to $1$, because $f(y)$ is a proper
density function and it integrates to $1$.

Now recall the [Bayes' theorem](https://en.wikipedia.org/wiki/Bayes'_theorem):

`$$
\begin{align}
  \Pr (A \mid B) = \frac{\Pr(B \mid A) \Pr(A)}{\Pr(B)} \label{eq:bayes}.
\end{align}
$$`

In our case

`$$
\begin{align}
\Pr(A) = &\ \Pr(Y \le y) \\
\Pr(B) = &\ \Pr \left( U \le \frac{f(Y)}{cg(Y)} \right) = p = \frac{1}{c} \label{eq:pr_B} ,
\end{align}
$$`

where (\ref{eq:pr_B}) is true, because it is the same as (\ref{eq:p}). Thereore,
with the above definitions of $A$ and $B$ (\ref{eq:bayes}) becomes

`$$
\begin{align}
\Pr \left( Y \le y \mid U \le \frac{f(Y)}{cg(Y)} \right)
  = &\ \Pr \left( U \le \frac{f(Y)}{cg(Y)}  \mid Y \le y \right) \times \frac{G(Y)}{\frac{1}{c}} \label{eq:bayes_substituted} .
\end{align}
$$`

From the definitions of
[conditional probability](https://en.wikipedia.org/wiki/Conditional_probability)
it follows that

`$$
\begin{align}
\Pr(B \mid A) = \frac{\Pr(B, A)}{\Pr(A)} ,
\end{align}
$$`

and therefore we can express a term in (\ref{eq:bayes_substituted}) as

`$$
\begin{align}
\Pr \left( U \le \frac{f(Y)}{cg(Y)}  \mid Y \le y \right)
  = &\ \frac{\Pr \left(U \le \frac{f(Y)}{cg(Y)} , \Pr(Y \le y \right)}{\Pr(Y \le y )} \nonumber \\
  = &\ \frac{\Pr \left(U \le \frac{f(Y)}{cg(Y)} , Y \le y \right)}{G(y)} .
\end{align}
$$`

We know that $Y$ and $U$ are statistically independent, therefore

`$$
\begin{align}
\frac{\Pr \left(U \le \frac{f(Y)}{cg(Y)} , Y \le y \right)}{G(y)}
  =&\ \frac{\Pr \left(U \le \frac{f(Y)}{cg(Y)} \mid Y \le y \right)}{G(y)} .
\end{align}
$$`

It is something very familiar. And indeed, it is almost the same equation as
(\ref{eq:U_cond_on_y_equality}), with the only difference being that instead of
$Y = y$, we now have $Y \le y$. Thus, we need to integrate it for all values of
$Y \in (-\infty; y)$ (also, note that $y$ is a constant and therefore we can
take $G(y)$ out of the integration sign):

`$$
\begin{align}
\frac{\Pr \left(U \le \frac{f(Y)}{cg(Y)} \mid Y \le y \right)}{G(y)}
  = &\ \frac{1}{G(Y)} \int_{-\infty}^{y} \frac{f(w)}{cg(w)} g(w) dw \nonumber \\
  = &\ \frac{1}{c G(Y)} \underbrace{\int_{-\infty}^{y} f(w) dw}_{F(y)} = \frac{F(y)}{cG(y)} \label{eq:U_cond_on_y_inequality}.
\end{align}
$$`

Substituting (\ref{eq:U_cond_on_y_inequality}) back into
(\ref{eq:bayes_substituted}) we get

`$$
\begin{align}
\Pr \left( Y \le y \mid U \le \frac{f(Y)}{cg(Y)} \right) = \frac{F(y)}{cG(y)} \times c G(Y) = F(y) .
\end{align}
$$`

Thus, accepting values $y$ sampled from a majorizing distribution with
probability $\frac{f(y)}{cg(y)}$ is the same as sampling from $F(y)$ directly.


## Notes

[^1]: As we will see later, this method depends only on the ratio of the target
distribution to an arbitrary distribution, which density is arbitrary scaled.
Thus, the method works even if only know a function to which the target
distribution is proportional: "target distribution is known up to a
multiplicative constant".
[^2]: Since $cg(x)$ is just a scaled version of $g(x)$, we will not show it on
the illustrations anymore.
[^3]: Technically, this is not probability, because we are talking about
continuous distributions, but this should be close enough for intuition.
[^4]: Proof is taken from [here](http://www.columbia.edu/~ks20/4703-Sigman/4703-07-Notes-ARM.pdf) with some comments.
