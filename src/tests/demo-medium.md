
This part will be ignored

<start/>

```
codeblock line 1
codeblock line 2
```

<append dest=front realm=tex>
<raw>% This will only appear in TeX source code before `\\begin{document}`</raw>
</append>

<append dest=front realm=html>
<raw>< !-- This will only appear in HTML source code in the `<head>` section --></raw>
</append>

> a blockquote...
> ```
> ...with code...
> ```
> ...is possible

simple paragraphs;
some shorter...


...some a bit longer

> A blockquote comes in handy.

<ignore>
ignored stuff
</ignore>
but at any rate
just
paragraphs

EOF
<stop/>

This part will be ignored