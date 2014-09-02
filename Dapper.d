
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

module Dapper;

import std.stdio;
import std.conv;

private immutable
{
		/**
		 * The beginning portion of every ANSI escape code supported by Dapper.
		 * "CSI" stands for "Control Sequence Introducer."
		 **/
	string CSI = "\033["; // \033 is octal for the ESC character.

		/**
		 * Used to separate multiple parameters introduced by a single $(MREF CSI)
		 * and terminated by a single terminator.
		 *
		 * Examples:
		 * ---
		 * // The text "Hello, world" will appear bolded as well as green.
		 * writeln(CSI, SGR_TEXT_GREEN, SEPARATOR, SGR_BOLD, SGR_TERMINATOR);
		 * writeln("Hello, world!");
		 * writeln(CSI, SGR_RESET, SGR_TERMINATOR);
		 * ---
		 **/
	string SEPARATOR = ";";

		/**
		 * Terminator for moving the terminal cursor to a new location, to make output
		 * appear in a different place.
		 *
		 * The preceding two parameters (separated with $(MREF SEPARATOR)
		 * should point to the new row and column number, in that order, with row 1
		 * being the topmost row and column 1 being the leftmost column.
		 * If either of these parameters is left blank, it defaults to 1.
		 *
		 * Examples:
		 * ---
		 * writeln(CSI, 1, SEPARATOR, 5, MOVE_CURSOR_TERMINATOR); // Move to row 1, column 5.
		 * writeln(CSI, SEPARATOR, 5, MOVE_CURSOR_TERMINATOR); // Same as above.
		 * writeln(CSI, 7, SEPARATOR, MOVE_CURSOR_TERMINATOR); // Move to row 7, column 1.
		 * ---
		 **/
	string MOVE_CURSOR_TERMINATOR = "H";

		/**
		 * Terminators for erasing all or part of the terminal screen.
		 * No parameter is needed.
		 * $(UL
		 * $(LI $(D _CLEAR_SCREEN_TERMINATOR) clears the screen entirely.  This is what is usually desired.)
		 * $(LI $(D CLEAR_AFTER_TERMINATOR) erases everything after the cursor (down to the bottom of the screen).)
		 * $(LI $(D CLEAR_BEFORE_TERMINATOR) erases everything before the cursor (up to the top of the screen).)
		 * )
		 * Some terminals simply output a bunch of blank lines to push the screen
		 * out of view rather than actually erasing it.  If that's unacceptable for
		 * your purposes, See the example below for a workaround.
		 *
		 * Examples:
		 * ---
		 * // Clears the screen.  May just print a bunch of blank lines.
		 * writeln(CSI, CLEAR_SCREEN_TERMINATOR);
		 *
		 * // Workaround: Move the cursor to the top-left and clear everything
		 * // after it to really erase the screen's contents.  Notice how write is
		 * // used instead of writeln to avoid dislodging the cursor with a newline.
		 * write(CSI, 1, SEPARATOR, 1, MOVE_CURSOR_TERMINATOR);
		 * write(CSI, CLEAR_AFTER_TERMINATOR);
		 * ---
		 **/
	string CLEAR_SCREEN_TERMINATOR = "2J";
	string CLEAR_BEFORE_TERMINATOR = "1J"; /// ditto
	string CLEAR_AFTER_TERMINATOR = "0J"; /// ditto

		/**
		 * Change the visibility of the terminal cursor.  No parameter is needed.
		 *
		 * Examples:
		 * ---
		 * writeln(CSI, HIDE_CURSOR_TERMINATOR);
		 * writeln(CSI, SHOW_CURSOR_TERMINATOR);
		 * ---
		 **/
	string HIDE_CURSOR_TERMINATOR = "?25l";
	string SHOW_CURSOR_TERMINATOR = "?25h"; /// ditto

		/**
		 * The ending of every Select Graphic Rendition code.  SGR codes are a subset
		 * of ANSI escape codes that control the appearance of text.  See below for
		 * a list of possible parameters.
		 **/
	string SGR_TERMINATOR = "m";

		/**
		 * SGR parameters to change the color of text or the background behind it.
		 * 
		 * Note that if the user has a custom color scheme installed, it may affect
		 * these predefined colors.  In such cases, these codes can actually
		 * display colors entirely different from what's advertised.
		 *
		 * Examples:
		 * ----
		 * writeln(CSI, SGR_TEXT_RED, SEPARATOR, SGR_BG_BLACK, SGR_TERMINATOR);
		 * writeln("Red text on a black background.");
		 * writeln(CSI, SGR_RESET, SGR_TERMINATOR);
		 * ----
		 **/
	string SGR_TEXT_BLACK = "30";
	string SGR_TEXT_RED = "31"; /// ditto
	string SGR_TEXT_GREEN = "32"; /// ditto
	string SGR_TEXT_YELLOW = "33"; /// ditto
	string SGR_TEXT_BLUE = "34"; /// ditto
	string SGR_TEXT_MAGENTA = "35"; /// ditto
	string SGR_TEXT_CYAN = "36"; /// ditto
	string SGR_TEXT_WHITE = "37"; /// ditto

	string SGR_BG_BLACK = "40"; /// ditto
	string SGR_BG_RED = "41"; /// ditto
	string SGR_BG_GREEN = "42"; /// ditto
	string SGR_BG_YELLOW = "43"; /// ditto
	string SGR_BG_BLUE = "44"; /// ditto
	string SGR_BG_MAGENTA = "45"; /// ditto
	string SGR_BG_CYAN = "46"; /// ditto
	string SGR_BG_WHITE = "47"; /// ditto

		/**
		 * SGR parameter that reverts the text or background color to whatever it would have been
		 * before any color code was applied.
		 *
		 * These default colors don't necessarily match any of the color presets
		 * defined above.  Therefore, when you want to go back to "normal-colored text,"
		 * you should use these.
		 **/
	string SGR_TEXT_COLORLESS = "39"; /// ditto
	string SGR_BG_COLORLESS = "49"; /// ditto

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

		/**
		 * SGR parameter for making text bolder and/or brighter.  The exact behavior
		 * depends on the terminal and how it's configured.
		 *
		 * Examples:
		 * ---
		 * writeln(CSI, SGR_BOLD, SGR_TERMINATOR, "This text will appear bold.");
		 * writeln(CSI, SGR_NO_BOLD, SGR_TERMINATOR, "Back to normal.");
		 * ---
		 **/
	string SGR_BOLD = "1";
	string SGR_NO_BOLD = "22"; /// ditto

		/**
		 * SGR parameter for making text blink indefinitely.
		 * 
		 * Only the text itself blinks; the background behind it remains constant.
		 * Sections of text output with this parameter always blink in-sync with each other.
		 *
		 * Examples:
		 * ---
		 * writeln(CSI, SGR_BLINK, SGR_TERMINATOR, "This text will blink.");
		 * writeln(CSI, SGR_NO_BLINK, SGR_TERMINATOR, "Back to normal.");
		 * ---
		 **/
	string SGR_BLINK = "5";
	string SGR_NO_BLINK = "25"; /// ditto

		/**
		 * SGR parameter for underlining text.
		 *
		 * ---
		 * writeln(CSI, SGR_UNDERLINE, SGR_TERMINATOR, "This text will be underlined.");
		 * writeln(CSI, SGR_NO_UNDERLINE, SGR_TERMINATOR, "Back to normal.");
		 * ---
		 **/
	string SGR_UNDERLINE = "4";
	string SGR_NO_UNDERLINE = "24"; /// ditto

		/**
		 * Resets the text's appearance to a clean slate, without any special
		 * formatting applied.
		 *
		 * In practice, this is equivalent to using $(MREF SGR_TEXT_COLORLESS),
		 * $(MREF SGR_BACKGROUND_COLORLESS), $(MREF SGR_NO_BOLD), etc. all at once.
		 *
		 * Examples:
		 * ----
		 * writeln(CSI, SGR_TEXT_RED, SGR_TERMINATOR, "This line of text will be red.");
		 * writeln("This will still be red.");
		 * writeln(CSI, SGR_RESET, SGR_TERMINATOR, "This will be the default color again.");
		 * ----
		 **/
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
	auto black     = Formatter(SGR_TEXT_BLACK);
	auto red       = Formatter(SGR_TEXT_RED);     /// ditto
	auto green     = Formatter(SGR_TEXT_GREEN);   /// ditto
	auto yellow    = Formatter(SGR_TEXT_YELLOW);  /// ditto
	auto blue      = Formatter(SGR_TEXT_BLUE);    /// ditto
	auto magenta   = Formatter(SGR_TEXT_MAGENTA); /// ditto
	auto cyan      = Formatter(SGR_TEXT_CYAN);    /// ditto
	auto white     = Formatter(SGR_TEXT_WHITE);   /// ditto
	
	auto blackBG   = Formatter(SGR_BG_RED);       /// ditto
	auto redBG     = Formatter(SGR_BG_RED);       /// ditto
	auto greenBG   = Formatter(SGR_BG_GREEN);     /// ditto
	auto yellowBG  = Formatter(SGR_BG_YELLOW);    /// ditto
	auto blueBG    = Formatter(SGR_BG_BLUE);      /// ditto
	auto magentaBG = Formatter(SGR_BG_MAGENTA);   /// ditto
	auto cyanBG    = Formatter(SGR_BG_CYAN);      /// ditto
	auto whiteBG   = Formatter(SGR_BG_WHITE);     /// ditto
	
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
	auto noColor   = Formatter(SGR_TEXT_COLORLESS);
	auto noColorBG = Formatter(SGR_BG_COLORLESS); /// ditto
	
		/**
		 * Formatters to enable or disable font boldness, respectively.
		 * 
		 * Many terminals make the text bright in addition to - or instead of - the text being bold.
		 **/
	auto bold   = Formatter(SGR_BOLD);
	auto noBold = Formatter(SGR_NO_BOLD); /// ditto
	
		/**
		 * Formatters to make the text blink indefinitely or turn blinking off, respectively.
		 *
		 * Only the text itself blinks; the background behind it remains constant.
		 * Sections of text output with this formatter blink in-sync with each
		 * each other, even if the sections aren't contiguous.
		 **/
	auto blink   = Formatter(SGR_BLINK);
	auto noBlink = Formatter(SGR_NO_BLINK); /// ditto
	
		/**
		 * Formatters to enable or disable text underlining, respectively.
		 **/
	auto underline   = Formatter(SGR_UNDERLINE);
	auto noUnderline = Formatter(SGR_NO_UNDERLINE); /// ditto
	
		/**
		 * Formatter for clearing the text and its background of all formatting effects.
		 *
		 * While this is the same in practice as using $(D NoColor), $(D NoColorBG),
		 * $(D NoBold), etc. all at once, this also disables formatting effects that
		 * Dapper does not support.
		 **/
	auto noFormatting = Formatter(SGR_RESET);
	
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
	alias customColor   = Create256ColorFormatter!SGR_TEXT_256_COLOR;
	alias customColorBG = Create256ColorFormatter!SGR_BG_256_COLOR; /// ditto
}
