	/**
	 * Dapper - Stylish ANSI terminal support for D.
	 * 
	 * See ReadMe.md for an introduction and API reference.
	 * 
	 * 
	 * License: The MIT License (MIT)
	 * 
	 * Copyright (c) 2013 Max Marrone
	 * 
	 * Permission is hereby granted, free of charge, to any person obtaining a copy of
	 * this software and associated documentation files (the "Software"), to deal in
	 * the Software without restriction, including without limitation the rights to
	 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
	 * the Software, and to permit persons to whom the Software is furnished to do so,
	 * subject to the following conditions:
	 * 
	 * The above copyright notice and this permission notice shall be included in all
	 * copies or substantial portions of the Software.
	 * 
	 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
	 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
	 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
	 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
	 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	 **/

module Dapper;

import std.stdio;
import std.conv;

private immutable
{
	string CSI = "\033["; // \033 is octal for the ESC character.
	string SGR_RESET = "0";
	string SGR_TERMINATOR = "m";
}

// Converts RGB coordinates to an XTerm 256-color palette index.
private @safe nothrow pure ubyte rgbToXterm(double red, double green, double blue)
in
{
	assert(red   >= 0.0 && red   <= 1.0, "RGB channels should be from 0 to 1.");
	assert(green >= 0.0 && green <= 1.0, "RGB channels should be from 0 to 1.");
	assert(blue  >= 0.0 && blue  <= 1.0, "RGB channels should be from 0 to 1.");
}
body
{
	// Convert from 0-1 to 0-5, rounding to the nearest integer.
	const uint integralRed   = cast(uint)(  red*5 + 0.5);
	const uint integralGreen = cast(uint)(green*5 + 0.5);
	const uint integralBlue  = cast(uint)( blue*5 + 0.5);
	
	return cast(ubyte)(16 + integralRed*36 + integralGreen*6 + integralBlue);
}

public struct Formatter
{
	string sgrParameters;
	
	@safe nothrow pure this(const string sgrParameters...)
	{
		this.sgrParameters = sgrParameters;
	}
	
	@safe nothrow pure ArgumentRelayer opCall(Types...)(Types incomingArguments) const
	{
		string[] outgoingArguments;
		
		foreach (incomingArgument; incomingArguments)
		{
			// If this formatter has received a pack of arguments relayed from
			// a more deeply-nested one, it needs to apply the code to each of
			// those relayed arguments individually.
			static if (is(typeof(incomingArgument) == ArgumentRelayer))
			{	
				ArgumentRelayer incomingArgumentRelayer = incomingArgument;
				foreach (string relayedArgument; incomingArgumentRelayer.arguments)
				{
					outgoingArguments ~= (CSI ~ sgrParameters ~ SGR_TERMINATOR ~ relayedArgument);
				}
			}
			
			// The argument didn't come from another formatter, which means
			// it was passed in directly by calling code.  Therefore, it
			// needs to be converted here to a string (if it isn't one already).
			else
			{
				// Using to!string emulates writeln's flexibility with the types
				// of its arguments.  Calling code doesn't have to cast anything
				// that it wants to output through a formatter.
				outgoingArguments ~= (CSI ~ sgrParameters ~ SGR_TERMINATOR ~ to!string(incomingArgument));
			}
		}
		
		// Pass the arguments on to the enclosing level of the nest.
		return ArgumentRelayer(outgoingArguments);
	}
}

	/**
	 * Helper struct used to preserve the separateness of arguments passed
	 * to deeply-nested formatters.  When an argument passed to a formatter
	 * is of this type, it basically signals to that formatter that this came
	 * from another formatter and that it must be handled specially so
	 * that nesting works.
	 *
	 * For example, in red(green("A", "B"), "C"), the red formatter receives
	 * "A" and "B" in an ArgumentRelayer so that it can work with them
	 * separately instead of as a single argument "AB."
	 *
	 * At the outermost layer of the nest, writeln receives the ArgumentRelayers
	 * and sees that they have the toString() member function defined.  When
	 * writeln calls an ArgumentRelayer's toString(), the ArgumentRelayer
	 * concatenates its contained text into its final outputted form.
	 **/
private struct ArgumentRelayer
{
	string[] arguments;
	
	string toString() const
	{
		string concatenatedArguments;
		foreach (argument; arguments)
		{
			concatenatedArguments ~= argument;
			
			// The Formatter that created this ArgumentRelayer has
			// already prepended all the necessary SGR codes to the contained
			// arguments.  It has not, however, appended the reset code.
			// That must be done here so that the next argument starts from
			// a clean formatting state, and so the formatting state from the
			// last argument doesn't persist to any text that comes after it
			// that should be unformatted.
			//
			// The reason that this is done here instead of from within
			// Formatter.opCall() is to avoid arguments being appended
			// with many redundant reset codes as they propagate through many
			// layers of Formatters.
			concatenatedArguments ~= CSI ~ SGR_RESET ~ SGR_TERMINATOR;
		}
		return concatenatedArguments;
	}
	
	// ArgumentRelayers must occasionally be casted manually by calling code,
	// and the "cast(string)Foo" syntax is nicer than making people import std.conv
	// so they can use "to!string(Foo)."
	string opCast(Type:string)() const { return toString(); }
}

public @safe nothrow pure Formatter customColor(double r, double g, double b)
{
	return Formatter("38;5;" ~ to!string(rgbToXterm(r, g, b)));
}

public @safe nothrow pure Formatter customColorBG(double r, double g, double b)
{
	return Formatter("48;5;" ~ to!string(rgbToXterm(r, g, b)));
}

immutable public
{	
	Formatter defaultColor   = Formatter("39");
	Formatter black          = Formatter("30");
	Formatter red            = Formatter("31");
	Formatter green          = Formatter("32");
	Formatter yellow         = Formatter("33");
	Formatter blue           = Formatter("34");
	Formatter magenta        = Formatter("35");
	Formatter cyan           = Formatter("36");
	Formatter white          = Formatter("37");
	
	Formatter defaultColorBG = Formatter("49");
	Formatter blackBG        = Formatter("40");
	Formatter redBG          = Formatter("41");
	Formatter greenBG        = Formatter("42");
	Formatter yellowBG       = Formatter("43");
	Formatter blueBG         = Formatter("44");
	Formatter magentaBG      = Formatter("45");
	Formatter cyanBG         = Formatter("46");
	Formatter whiteBG        = Formatter("47");
	
	Formatter bold           = Formatter("1");
	Formatter noBold         = Formatter("22");
	
	Formatter blink          = Formatter("5");
	Formatter noBlink        = Formatter("25");
	
	Formatter underline      = Formatter("4");
	Formatter noUnderline    = Formatter("24");
	
	Formatter noFormatting   = Formatter(SGR_RESET);
}
