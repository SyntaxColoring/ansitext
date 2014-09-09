Introduction
============
`ansitext` provides D support for the text formatting subset of
[ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code).  ANSI
escape codes are a set of special output sequences that let you do things like
output colored text or clear part of the terminal window.

`ansitext` is licensed under the permissive
[MIT license](http://choosealicense.com/licenses/mit/).  See the top of
[ansitext.d](/ansitext.d) for details.

Usage Example
=============

![Screenshot of example output](Example.png)

```d
import std.stdio;
import ansitext;

void main()
{
	writeln("Normal text.");
	
	writeln(bold("Bold text."));
	
	writeln(blue("Blue text."));
	
	writeln(greenBG("Text with a green background."));
	
	writeln("Formatters can be applied to ", blue("portions"), " of text.");
	
	writeln("Formatters ",
	        yellowBG("can be ", blue("nested"), " and ", blue("combined.")));
}
```

Features
========
- Formatters for bold, underlined and blinking text
- Text color and background color formatters for the 8 system-defined colors
- Define your own text and background colors by their RGB components
- Mix, match, nest and merge formatters to combine their effects any way you like
- Output function agnostic - use `writeln` from the standard library, or
  something else if you prefer
- Lightweight and extensible API

API Reference
=============

Formatter Listing: Colors
-------------------------

| For text       | For background   |
| -------------- | ---------------- |
| `defaultColor` | `defaultColorBG` |
| `black`        | `blackBG`        |
| `red`          | `redBG`          |
| `green`        | `greenBG`        |
| `yellow`       | `yellowBG`       |
| `blue`         | `blueBG`         |
| `magenta`      | `magentaBG`      |
| `cyan`         | `cyanBG`         |
| `white`        | `whiteBG`        |

The exact colors visible on the screen can be anything, depending on the host
terminal and how it's configured.  If you need more consistency, you might
want to look into creating your own color formatter (see below).

Formatter Listing: Other Formatters
-----------------------------------

| Other formatters |
| ---------------- |
| `noFormatting`   |
| `blink`          |
| `noBlink`        |
| `bold`           |
| `noBold`         |
| `underline`      |
| `noUnderline`    |

Making Your Own Color Formatters
--------------------------------

The predefined colors listed above are usually good enough, but sometimes you
need to make your own.  To do so, use the `customColor()` and `customBGColor()`
functions, which take RGB values and return new formatters.

```d
// Define a color by its red, green and blue components (each from 0.0 to 1.0).
auto pink = customColor(1.0, 0.08, 0.58);
auto pinkBG = customColorBG(1.0, 0.08, 0.58);

// Use your new formatters the same way you use the predefined ones.
writeln("Pretty in ", pinkBG("pink."));
```

Alternatively, you can create your custom color formatter inline:

```d
writeln("Pretty in ", customColorBG(1.0, 0.08, 0.58)("pink."));
```

Merging Formatters
------------------

Sometimes, you might find yourself using the same combination of formatters
over and over again, like this:

```d
                               // Repetitive and annoying to type.
writeln("Highlight ",          bold(white(yellowBG("this,"))));
writeln("and also highlight ", bold(white(yellowBG("that."))));
```

In such cases, it might be convenient to *merge* those formatters into one.  The
`merge()` function returns a new formatter created from the combined effects of
whatever formatters you pass it.  Use it like this:

```d
auto highlight = merge(bold, white, yellowBG);

writeln("Highlight ",          highlight("this,"));
writeln("and also highlight ", highlight("that."));
```

Merging formatters like this can improve readability and maintainability.
