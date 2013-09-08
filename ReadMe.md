**This project is very incomplete at the moment!**

-----
Overview
========

Dapper is a lightweight D library that lets you stylize your standard output.  Sections of text can easily be colored, underlined, bolded and otherwise formatted in various ways.

The API tries to be as intuitive and unobtrusive as possible.  The aim is to have the library enhance your programs, rather than forcing you to write your programs around the library.  [`Dapper.Output`](http://syntaxcoloring.github.io/Dapper/Dapper.Output.html) provides a plethora of functions to format your output in a simple, convenient way.

Those formatting effects are implemented with [ANSI escape codes](http://en.wikipedia.org/wiki/Ansi_escape_code) under the hood, but you never need to worry about that unless you want to - in which case, Dapper won't get in the way.  The [`Dapper.Codes`](http://syntaxcoloring.github.io/Dapper/Dapper.Codes.html) module is there to help if you want to deal with raw escape codes.

For examples and a full reference, see the [documentation pages](http://syntaxcoloring.github.io/Dapper).
