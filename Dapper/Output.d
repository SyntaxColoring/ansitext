
	/**
	 * Conveniently format terminal output in various ways.
	 *
	 * Formatting_Functions:
	 * Formatting functions work from within the standard $(STDREF stdio, write)
	 * and $(STDREF stdio, writeln) output functions, like so:
	 *
	 * ---
	 * writeln("One fish two fish ", Red("red fish "), Blue("blue fish")); // "Red fish" and "blue fish" will be in color in the terminal window.
	 * ---
	 *
	 * Like $(D writeln), the formatting functions accept any number and type
	 * of arguments:
	 *
	 * ---
	 * writeln(1, " fish ", 1 + 1, " fish"); // Prints "1 fish 2 fish"
	 * writeln(Green(1, " fish ", 1 + 1, " fish")); // Same thing, only now the text will be green.
	 * ---
	 *
	 * All formatting functions can nest seamlessly within one another.  There's no limit
	 * imposed on how deeply the nesting can go.
	 *
	 * ---
	 * // "Never press the red button!"
	 * writeln(Underline(Bold("Never"), " press the ", Red("red button!")); // Everything underlined, "never" bolded and "red button" in red.
	 *
	 * // "The D programming language"
	 * writeln(WhiteBG("The ", RedBG("D"), " programming language")); // "D" has a red background; everything else, white.
	 *
	 * // "OoOoO You're under arrest! OoOoO"
	 * writeln(Blue(Blink("OoOoO ", NoFormatting("You're under arrest!"), " OoOoO"))); // The "O"s are blue and blinking.
	 * ---
	 *
	 * $(B Note:) Use $(D ,) (comma) instead of $(D ~) for concatenating text from
	 * nested formatting functions.  Formatting functions that aren't nested at all
	 * or that form the outermost layer of the nest $(EM can) be safely concatenated if they're
	 * cast to a string beforehand.  This lets you use the formatting functions with
	 * $(STDREF stdio, writef) format strings, if you so choose.  However, there's no
	 * built-in check to make sure that what you're casting is unnested or on the
	 * outermost layer, so be careful.
	 * 
	 * ---
	 * writeln(Green(Underline("Hello") ~ " world!")); // Compilation error.
	 * writeln(Green(cast(string)(Underline("Hello")) ~ " world!")); // Compiles, but won't display correctly.
	 *
	 * writeln(Green(Underline("Hello"), " world!")); // Works fine.
	 *
	 * string formatString = "Date: " ~ cast(string)Underline("%2$s") ~ " %1$s";
	 * writefln(formatString, "October", 5); // Also works fine.  "Date: 5 October" with the 5 underlined.
	 * ---
	 **/

module Dapper.Output;

import Dapper.Codes;

import std.stdio;
import std.conv;

private
{
		/**
		 * Internally-used functor used to implement formatters like Red() and
		 * their ability to nest properly within each other.
		 *
		 * The library initializes a NestableFormatter with an SGR parameter.
		 * Afterwards, when it is called as a function in calling code, that
		 * SGR parameter is applied to each of the arguments that the calling code
		 * passed in to be output.  This is done in a way designed to work with nesting.
		 *
		 * This simplifies the implementation of the library.  Rather than having discrete
		 * functions for making text colored, bold, underlined, etc., all the important logic
		 * for formatting can live here in one place.
		 **/
	struct NestableFormatter
	{
			/**
			 * Helper struct used to preserve the separateness of arguments passed
			 * to deeply-nested formatters.  When an argument passed to a formatter
			 * is of this type, it basically signals to that formatter that this came
			 * from another formatter and that it must be handled specially so
			 * that nesting works.
			 * 
			 * The outer layers need to apply their codes to each argument individually
			 * to ensure proper nesting, so the inner layers have to return this
			 * instead of concatenating all their arguments into a single string.
			 * The arguments are concatenated in this struct's toString() member
			 * function, which is called by writeln after all the formatters have
			 * done their work.
			 **/
		private struct ArgumentRelayer
		{
			string[] Arguments;
			
			string toString() const
			{
				string ConcatenatedArguments;
				foreach (Argument; Arguments)
				{
					ConcatenatedArguments ~= Argument;
					ConcatenatedArguments ~= CSI ~ SGR_RESET ~ SGR_TERMINATOR;
				}
				return ConcatenatedArguments;
			}
			
			string opCast(Type:string)() { return toString(); }
		}
		
		private const string SGRParameter;
		
		@disable this();
		this(const string SGRParameter) { this.SGRParameter = SGRParameter; }
		
		ArgumentRelayer opCall(Types...)(Types IncomingArguments) const
		{
			string[] OutgoingArguments;
			
			foreach (IncomingArgument; IncomingArguments)
			{
				// If this formatter has received a pack of arguments relayed from
				// a more deeply-nested one, it needs to apply the code to each of
				// those relayed arguments individually.
				static if (is(typeof(IncomingArgument) == ArgumentRelayer))
				{	
					ArgumentRelayer IncomingArgumentRelayer = IncomingArgument;
					foreach (string RelayedArgument; IncomingArgumentRelayer.Arguments)
					{
						OutgoingArguments ~= (CSI ~ SGRParameter ~ SGR_TERMINATOR ~ RelayedArgument);
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
					OutgoingArguments ~= (CSI ~ SGRParameter ~ SGR_TERMINATOR ~ to!string(IncomingArgument));
				}
			}
			
			// Pass the arguments on to the enclosing level of the nest.
			return ArgumentRelayer(OutgoingArguments);
		}
	}
	
		/**
		 * Functor for supporting xterm 256 colors.
		 *
		 * Calling code instantiates this functor, but it still doesn't call it
		 * by name.  Instead, it's accessed by aliases that take care of the
		 * template parameter.
		 *
		 * The reason that template parameter is necessary is to factor out the
		 * distinction between setting the text color and setting the background
		 * color.
		 **/
	template NestableCustomColorFormatter(const string SGRParameter)
	{
		struct NestableCustomColorFormatter
		{
			private const NestableFormatter InternalFormatter;
			
			@disable this();
			
			this(const uint ColorCode)
			in { assert (ColorCode < 256); }
			body
			{
				string Code = SGRParameter ~ SEPARATOR ~ to!string(ColorCode);
				InternalFormatter = NestableFormatter(Code);
			}
			
			this(const double Red, const double Green, const double Blue)
			in
			{
				assert (0.0 <= Red && Red <= 1.0);
				assert (0.0 <= Green && Green <= 1.0);
				assert (0.0 <= Blue && Blue <= 1.0);
			}
			body
			{
				const uint IntegralRed = cast(uint)(Red * 5 + 0.5);
				const uint IntegralGreen = cast(uint)(Green * 5 + 0.5);
				const uint IntegralBlue = cast(uint)(Blue * 5 + 0.5);
				
				const uint ColorCode = IntegralRed*36 + IntegralGreen*6 + IntegralBlue + 16;
				
				this(ColorCode);
			}
			
			string opCall(Types...)(Types ContainedArguments) const
			{
				return InternalFormatter(ContainedArguments);
			}
		}
	}
}

immutable
{
	auto Black        = NestableFormatter(SGR_TEXT_BLACK);
	auto Red          = NestableFormatter(SGR_TEXT_RED);
	auto Green        = NestableFormatter(SGR_TEXT_GREEN);
	auto Yellow       = NestableFormatter(SGR_TEXT_YELLOW);
	auto Blue         = NestableFormatter(SGR_TEXT_BLUE);
	auto Magenta      = NestableFormatter(SGR_TEXT_MAGENTA);
	auto Cyan         = NestableFormatter(SGR_TEXT_CYAN);
	auto White        = NestableFormatter(SGR_TEXT_WHITE);
	auto Colorless    = NestableFormatter(SGR_TEXT_COLORLESS);
	
	auto BlackBG      = NestableFormatter(SGR_BG_RED);
	auto RedBG        = NestableFormatter(SGR_BG_RED);
	auto GreenBG      = NestableFormatter(SGR_BG_GREEN);
	auto YellowBG     = NestableFormatter(SGR_BG_YELLOW);
	auto BlueBG       = NestableFormatter(SGR_BG_BLUE);
	auto MagentaBG    = NestableFormatter(SGR_BG_MAGENTA);
	auto CyanBG       = NestableFormatter(SGR_BG_CYAN);
	auto WhiteBG      = NestableFormatter(SGR_BG_WHITE);
	auto ColorlessBG  = NestableFormatter(SGR_BG_COLORLESS);
	
	auto Bold         = NestableFormatter(SGR_BOLD);
	auto NoBold       = NestableFormatter(SGR_NO_BOLD);
	
	auto Blink        = NestableFormatter(SGR_BLINK);
	auto NoBlink      = NestableFormatter(SGR_NO_BLINK);
	
	auto Underline    = NestableFormatter(SGR_UNDERLINE);
	auto NoUnderline  = NestableFormatter(SGR_NO_UNDERLINE);
	
	auto NoFormatting = NestableFormatter(SGR_RESET);
	
	alias NestableCustomColorFormatter!SGR_TEXT_256_COLOR CustomColor;
	alias NestableCustomColorFormatter!SGR_BG_256_COLOR CustomColorBG;
}

// TODO: Figure out x-y vs. row-col, 1-index vs. 0-index.
// Remember to update Clear!
void MoveCursor(const uint Row, const uint Column)
{
	write(CSI, Row, SEPARATOR, Column, MOVE_CURSOR_TERMINATOR);
}

void SetCursorVisibility(const bool Visible)
{
	write(CSI, (Visible ? SHOW_CURSOR_TERMINATOR : HIDE_CURSOR_TERMINATOR));
}

void Clear(ClearMode Portion = ClearMode.ENTIRE_SCREEN)
{
	if (Portion == ClearMode.ENTIRE_SCREEN)
	{
		MoveCursor(1, 1);
		Clear(ClearMode.AFTER_CURSOR);
	}
	else write(CSI, cast(string)Portion);
}

enum ClearMode: string
{
	ENTIRE_SCREEN = "",
	ENTIRE_SCREEN_ALLOW_SCROLL = CLEAR_SCREEN_TERMINATOR,
	BEFORE_CURSOR = CLEAR_BEFORE_TERMINATOR,
	AFTER_CURSOR = CLEAR_AFTER_TERMINATOR
}
