
	/**
	 * Conveniently format terminal output in various ways.
	 *
	 * Formatters:
	 * Formatters change the appearance of text.  They work from within the standard
	 * $(STDREF stdio, write) and $(STDREF stdio, writeln) output functions, like so:
	 * ---
	 * writeln("One fish two fish ", Red("red fish "), Blue("blue fish")); // "Red fish" and "blue fish" will be in color in the terminal window.
	 * ---
	 * Like $(D writeln), formatters accept any number and type
	 * of arguments:
	 * ---
	 * writeln(1, " fish ", 1 + 1, " fish"); // Prints "1 fish 2 fish"
	 * writeln(Green(1, " fish ", 1 + 1, " fish")); // Same thing, only now the text will be green.
	 * ---
	 * All formatters can nest seamlessly within one another.  There's no limit
	 * imposed on how deeply the nesting can go.
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
	 * $(B Note on concatenation:) Use $(D ,) (comma) instead of $(D ~) for concatenating text from
	 * nested formatters.  Only formatters that aren't nested at all
	 * or that form the outermost layer of the nest can be safely concatenated - just
	 * cast them to a string beforehand.  This lets you use the formatters with
	 * $(STDREF stdio, writef) format strings, if you so choose.  However, there's no
	 * built-in check to make sure that what you're casting is unnested or on the
	 * outermost layer, so be careful.
	 * ---
	 * writeln(Green(Underline("Hello") ~ " world!")); // Compilation error.
	 * writeln(Green(cast(string)(Underline("Hello")) ~ " world!")); // Compiles, but won't display correctly.
	 *
	 * writeln(Green(Underline("Hello"), " world!")); // Works fine.
	 *
	 * string formatString = "Date: " ~ cast(string)Underline("%2$s") ~ " %1$s";
	 * writefln(formatString, "October", 5); // Also works fine.  "Date: 5 October" with the 5 underlined.
	 * ---
	 * See the reference documentation below for a full list of formatters.
	 *
	 *
	 * Other_Functions:
	 * This module also contains a few regular functions that operate outside $(D writeln): 
	 * $(UL
	 * $(LI $(MREF MoveCursor))
	 * $(LI $(MREF SetCursorVisibility))
	 * $(LI $(MREF Clear))
	 * )
	 * 
	 * See_Also:
	 * $(DPMODULE Codes), which provides the foundation for this module.
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
			 * For example, in Red(Green("A", "B"), "C"), the Red formatter receives
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
			string[] Arguments;
			
			string toString() const
			{
				string ConcatenatedArguments;
				foreach (Argument; Arguments)
				{
					ConcatenatedArguments ~= Argument;
					
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
					ConcatenatedArguments ~= CSI ~ SGR_RESET ~ SGR_TERMINATOR;
				}
				return ConcatenatedArguments;
			}
			
			// ArgumentRelayers must occasionally be casted manually by calling code,
			// and the "cast(string)Foo" syntax is nicer than making people import std.conv
			// so they can use "to!string(Foo)."
			string opCast(Type:string)() const { return toString(); }
		}
		
		private const string SGRParameter;
		
		@disable this();
		this(const string SGRParameter) { this.SGRParameter = SGRParameter; }
		
		// This is what calling code calls.  writeln(Red("Foo")) is actually
		// writeln(Red.opCall("Foo")).
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

immutable
{
		/**
		 * Formatters for changing the text or background color to one of eight presets.
		 *
		 * These presets are defined by the terminal's color scheme.  Therefore,
		 * on some terminals, these formatters can actually result in completely
		 * different colors being displayed.  $(MREF CustomColor) does not have
		 * this problem.
		 **/
	auto Black     = Formatter(SGR_TEXT_BLACK);
	auto Red       = Formatter(SGR_TEXT_RED);     /// ditto
	auto Green     = Formatter(SGR_TEXT_GREEN);   /// ditto
	auto Yellow    = Formatter(SGR_TEXT_YELLOW);  /// ditto
	auto Blue      = Formatter(SGR_TEXT_BLUE);    /// ditto
	auto Magenta   = Formatter(SGR_TEXT_MAGENTA); /// ditto
	auto Cyan      = Formatter(SGR_TEXT_CYAN);    /// ditto
	auto White     = Formatter(SGR_TEXT_WHITE);   /// ditto
	
	auto BlackBG   = Formatter(SGR_BG_RED);       /// ditto
	auto RedBG     = Formatter(SGR_BG_RED);       /// ditto
	auto GreenBG   = Formatter(SGR_BG_GREEN);     /// ditto
	auto YellowBG  = Formatter(SGR_BG_YELLOW);    /// ditto
	auto BlueBG    = Formatter(SGR_BG_BLUE);      /// ditto
	auto MagentaBG = Formatter(SGR_BG_MAGENTA);   /// ditto
	auto CyanBG    = Formatter(SGR_BG_CYAN);      /// ditto
	auto WhiteBG   = Formatter(SGR_BG_WHITE);     /// ditto
	
		/**
		 * Formatters to set the text or background color to the default, normal color.
		 * 
		 * As above, these colors are defined by the terminal's configuration.
		 * However, these defaults aren't necessarily the same color as any of
		 * the above presets.  Therefore, when you want to go back to
		 * "normal-colored text," you should use these.
		 *
		 * Examples:
		 * ---
		 * writeln(CyanBG(Black(1, NoColorBG(2), 3))); // 1 and 3 will be black on cyan.  2 will be black on a normal background.
		 * 
		 * writeln(CyanBG(Black(1, NoColor(2), 3))); // 1 and 3 will be black on cyan.  2 will be normal text on a cyan background.
		 * ---
		 **/
	auto NoColor   = Formatter(SGR_TEXT_COLORLESS);
	auto NoColorBG = Formatter(SGR_BG_COLORLESS); /// ditto
	
		/**
		 * Formatters to enable or disable font boldness, respectively.
		 * 
		 * Many terminals make the text bright in addition to - or instead of - the text being bold.
		 **/
	auto Bold   = Formatter(SGR_BOLD);
	auto NoBold = Formatter(SGR_NO_BOLD); /// ditto
	
		/**
		 * Formatters to make the text blink indefinitely or turn blinking off, respectively.
		 *
		 * Only the text itself blinks; the background behind it remains constant.
		 * Sections of text output with this formatter blink in-sync with each
		 * each other, even if the sections aren't contiguous.
		 **/
	auto Blink   = Formatter(SGR_BLINK);
	auto NoBlink = Formatter(SGR_NO_BLINK); /// ditto
	
		/**
		 * Formatters to enable or disable text underlining, respectively.
		 **/
	auto Underline   = Formatter(SGR_UNDERLINE);
	auto NoUnderline = Formatter(SGR_NO_UNDERLINE); /// ditto
	
		/**
		 * Formatter for clearing the text and its background of all formatting effects.
		 *
		 * While this is the same in practice as using $(D NoColor), $(D NoColorBG),
		 * $(D NoBold), etc. all at once, this also disables formatting effects that
		 * Dapper does not support.
		 **/
	auto NoFormatting = Formatter(SGR_RESET);
	
		/**
		 * Functions for supporting colors beyond the 8 preset values.
		 *
		 * Don't let the ugly alias declaration fool you - they're actually quite simple.
		 * Give one of these functions an $(HTTP en.wikipedia.org/wiki/RGB_color_model, RGB)
		 * or $(HTTP en.wikipedia.org/wiki/Xterm, xterm 256 color) and it will return a
		 * formatter for you to use.  For example:
		 *
		 * ---
		 * auto BrightRed = CustomColor(1.0, 0.0, 0.0); // RGB is accepted as three doubles from 0.0 to 1.0.
		 * auto OrangeBG = CustomColorBG(208); // Colors from the xterm palette are accepted as a single uint from 0 to 255.
		 *
		 * // Having created the formatters, you can use them normally.
		 * writeln("Paint the town ", Red("red."));
		 * writeln("Here comes the ", OrangeBG("sun!"));
		 *
		 * // You can also create them inline, if that's more convenient.
		 * writeln("The grass is always ", CustomColor(0.0, 1.0, 0.0)("greener..."));
		 * ---
		 * Nesting works as it normally would, and $(MREF NoFormatting) and $(MREF NoColor)
		 * still work as expected with custom colors.
		 *
		 * Unlike the preset color formatters like $(MREF Black), these will look the
		 * same from terminal to terminal.  Keep in mind, though, that your text may
		 * be difficult to read if you use a custom text color without a custom background color
		 * (or vice versa).
		 **/
	alias CustomColor   = Create256ColorFormatter!SGR_TEXT_256_COLOR;
	alias CustomColorBG = Create256ColorFormatter!SGR_BG_256_COLOR; /// ditto
}
