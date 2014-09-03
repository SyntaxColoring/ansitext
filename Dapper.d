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
	
	string SEPARATOR = ";";
	
	string SGR_TERMINATOR = "m";
	
	string SGR_TEXT_BLACK = "30";
	string SGR_TEXT_RED = "31";
	string SGR_TEXT_GREEN = "32";
	string SGR_TEXT_YELLOW = "33";
	string SGR_TEXT_BLUE = "34";
	string SGR_TEXT_MAGENTA = "35";
	string SGR_TEXT_CYAN = "36";
	string SGR_TEXT_WHITE = "37";
	
	string SGR_BG_BLACK = "40";
	string SGR_BG_RED = "41";
	string SGR_BG_GREEN = "42";
	string SGR_BG_YELLOW = "43";
	string SGR_BG_BLUE = "44";
	string SGR_BG_MAGENTA = "45";
	string SGR_BG_CYAN = "46";
	string SGR_BG_WHITE = "47";
	
	string SGR_TEXT_COLORLESS = "39";
	string SGR_BG_COLORLESS = "49";
	
		/**
		 * SGR parameter that sets the text or background color using the
		 * $(HTTP upload.wikimedia.org/wikipedia/commons/9/95/Xterm_color_chart.png xterm 256 color palette.)
		 *
		 * The next parameter (separated by $(MREF SEPARATOR)) must be an integer from 0 to 255
		 * referencing the desired color.
		 * $(HTTP www.mudpedia.org/mediawiki/index.php/Xterm_256_colors#RGB_Colors Mudpedia)
		 * has a good description of how the palette works.  Note that colors 0-7 and 8-15 are equivalent
		 * to the color presets above without and with $(MREF SGR_BOLD), respectively.
		 *
		 * Unlike the color presets defined above, the terminal color scheme cannot
		 * override these colors.  The xterm 256 color palette is, however, a nonstandard extension,
		 * although it's basically ubiquitous in modern terminal emulators.
		 *
		 * Examples:
		 * ---
		 * writeln(CSI, SGR_TEXT_256_COLOR, SEPARATOR, 202, SGR_TERMINATOR);
		 * writeln("202 is orange in the xterm 256 palette, so this text will be orange.");
		 * writeln(CSI, SGR_RESET, SGR_TERMINATOR);
		 * ---
		 **/
	string SGR_TEXT_256_COLOR = "38" ~ SEPARATOR ~ "5";
	string SGR_BG_256_COLOR = "48" ~ SEPARATOR ~ "5"; /// ditto
	
	string SGR_BOLD = "1";
	string SGR_NO_BOLD = "22"; /// ditto
	
	string SGR_BLINK = "5";
	string SGR_NO_BLINK = "25"; /// ditto
	
	string SGR_UNDERLINE = "4";
	string SGR_NO_UNDERLINE = "24"; /// ditto
	
	string SGR_RESET = "0";
}

private
{
		/**
		 * Internally-used functor used to implement formatters like Red() and
		 * their ability to nest properly within each other.
		 *
		 * The library initializes a Formatter with an SGR parameter.
		 * Afterwards, when it is called as a function in calling code, that
		 * SGR parameter is applied to each of the arguments that the calling code
		 * passed in to be output.  This is done in a way designed to work with nesting.
		 *
		 * This simplifies the implementation of the library.  Rather than having discrete
		 * functions for making text colored, bold, underlined, etc., all the important logic
		 * for formatting can live here in one place.
		 **/
	struct Formatter
	{
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
		
		private const string sgrParameter;
		
		@disable this();
		this(const string sgrParameter) { this.sgrParameter = sgrParameter; }
		
		// This is what calling code calls.  writeln(red("Foo")) is actually
		// writeln(red.opCall("Foo")).
		ArgumentRelayer opCall(Types...)(Types incomingArguments) const
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
						outgoingArguments ~= (CSI ~ sgrParameter ~ SGR_TERMINATOR ~ relayedArgument);
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
					outgoingArguments ~= (CSI ~ sgrParameter ~ SGR_TERMINATOR ~ to!string(incomingArgument));
				}
			}
			
			// Pass the arguments on to the enclosing level of the nest.
			return ArgumentRelayer(outgoingArguments);
		}
	}
	
		/**
		 * Functions for supporting xterm 256 colors.
		 *
		 * These functions take an xterm-256 color as a parameter and return a
		 * formatter that applies the appropriate color code.
		 *
		 * The template parameter factors out the distinction between setting
		 * the background color and setting the text color.  It's only a difference
		 * of one digit in the ANSI escape code, and it would be silly to define
		 * two separate sets of functions just for that.
		 *
		 * Client code accesses these functions through aliases that take care of
		 * the template parameter.  (See "CustomColor" and "CustomColorBG" below.)
		 **/
	template Create256ColorFormatter(const string SGRParameter)
	{
		// The functions themselves need to be public within the template for the
		// aliases to work outside this module.  Even with them public, calling code
		// still can't access them directly because the enclosing template is private.
		public
		{
			Formatter Create256ColorFormatter(const uint ColorCode)
			in { assert (ColorCode < 256); }
			body
			{
				string Code = SGRParameter ~ SEPARATOR ~ to!string(ColorCode);
				return Formatter(Code);
			}
			
			Formatter Create256ColorFormatter(const double Red, const double Green, const double Blue)
			in
			{
				assert (0.0 <= Red && Red <= 1.0);
				assert (0.0 <= Green && Green <= 1.0);
				assert (0.0 <= Blue && Blue <= 1.0);
			}
			body
			{
				// Somewhat incomplete conversion from RGB to xterm 256.  The xterm
				// 256 palette has a separate grayscale ramp that this function
				// currently makes no attempt to take advantage of.  That means that
				// grayscale values passed to this function overload will end up being
				// displayed with a significantly lower precision than what they
				// potentially could be.
				const uint IntegralRed = cast(uint)(Red * 5 + 0.5);
				const uint IntegralGreen = cast(uint)(Green * 5 + 0.5);
				const uint IntegralBlue = cast(uint)(Blue * 5 + 0.5);
				
				const uint ColorCode = IntegralRed*36 + IntegralGreen*6 + IntegralBlue + 16;
				
				return Create256ColorFormatter!SGRParameter(ColorCode);
			}
		}
	}
}

immutable public
{
	auto black     = Formatter(SGR_TEXT_BLACK);
	auto red       = Formatter(SGR_TEXT_RED);
	auto green     = Formatter(SGR_TEXT_GREEN);
	auto yellow    = Formatter(SGR_TEXT_YELLOW);
	auto blue      = Formatter(SGR_TEXT_BLUE);
	auto magenta   = Formatter(SGR_TEXT_MAGENTA);
	auto cyan      = Formatter(SGR_TEXT_CYAN);
	auto white     = Formatter(SGR_TEXT_WHITE);
	
	auto blackBG   = Formatter(SGR_BG_BLACK);
	auto redBG     = Formatter(SGR_BG_RED);
	auto greenBG   = Formatter(SGR_BG_GREEN);
	auto yellowBG  = Formatter(SGR_BG_YELLOW);
	auto blueBG    = Formatter(SGR_BG_BLUE);
	auto magentaBG = Formatter(SGR_BG_MAGENTA);
	auto cyanBG    = Formatter(SGR_BG_CYAN);
	auto whiteBG   = Formatter(SGR_BG_WHITE);
	
	auto noColor   = Formatter(SGR_TEXT_COLORLESS);
	auto noColorBG = Formatter(SGR_BG_COLORLESS); /// ditto
	
	auto bold   = Formatter(SGR_BOLD);
	auto noBold = Formatter(SGR_NO_BOLD); /// ditto
	
	auto blink   = Formatter(SGR_BLINK);
	auto noBlink = Formatter(SGR_NO_BLINK); /// ditto
	
	auto underline   = Formatter(SGR_UNDERLINE);
	auto noUnderline = Formatter(SGR_NO_UNDERLINE); /// ditto
	
	auto noFormatting = Formatter(SGR_RESET);
	
	alias customColor   = Create256ColorFormatter!SGR_TEXT_256_COLOR;
	alias customColorBG = Create256ColorFormatter!SGR_BG_256_COLOR; /// ditto
}
