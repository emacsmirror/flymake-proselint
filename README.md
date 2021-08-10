# flymake-proselint

This package makes it possible to use [proselint](http://proselint.com/) with Emacs built-in Flymake.

## Getting started

`flymake-proselint` is listed on [ELPA](http://elpa.gnu.org/packages/vertico.html), so you can use <kbd>M-x list-packages</kbd> to install
it.

Then you just need to activate it in the modes you want your prose to be
checked with something like:

``` emacs-lisp
(add-hook 'text-mode-hook (lambda ()
                            (flymake-mode +1)
                            (flymake-proselint-setup)))
```


