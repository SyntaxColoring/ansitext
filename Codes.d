	/**
	 * Provides low-level mappings to the basic elements of common ANSI escape codes.
	 * Most people should use Dapper.Format instead of this module, since it
	 * provides all the same functionality at a higher level of abstraction.
	 * 
	 * ANSI escape codes are special sequences of text that can be
	 * output to give instructions to the terminal.  This is used to do things like
	 * change the text color or move the cursor position.
	 *
	 * If you opt to use this module instead of Dapper.Format, remember that these
	 * codes will remain activated until they are explicitly deactivated - even
	 * after your program stops running.  To avoid polluting the user's terminal
	 * window, remember to clean up with SGR_RESET.
	 *
	 * Standards:
	 * ANSI escape codes are somewhat ill-defined.  Every terminal emulator has its
	 * quirks, and many codes simply don't work except in rare cases.  This module
	 * tries to limit its support to the most common codes.  Even though this necessarily
	 * omits some codes that may be useful, it also means that the codes included
	 * here can be relied on working in most environments.
	 * 
	 * See_Also:
	 * Dapper.Format, $(LINK http://en.wikipedia.org/wiki/ANSI_escape_code)
	 **/
module Dapper.Codes;

immutable:

	/**
	 * The beginning portion of every ANSI escape code supported by Dapper.
	 * "CSI" stands for "Control Sequence Introducer."
	 **/
string CSI = "\033["; // \033 is octal for the ESC character.

	/**
	 * The ending of every Select Graphic Rendition code.  SGR codes are a subset
	 * of ANSI escape codes that control the appearance of text.
	 **/
string SGR_TERMINATOR = "m";

	/**
	 * Changes the color of all subsequently-output text.
	 *
	 * SGR_TEXT_COLORLESS reverts the text color to whatever it would have been
	 * before any other color codes were applied.  This default color isn't
	 * necessarily the same as any of the other presets.
	 * 
	 * Note that if the user has a custom color scheme installed, it may affect
	 * these predefined colors.  In cases like that, these codes can actually
	 * result in colors entirely different from what's advertised.
	 *
	 * Examples:
	 * ----
	 * writeln(CSI, SGR_TEXT_BLUE, SGR_TERMINATOR, "This text will appear blue.");
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
// 38 is skipped intentionally; it's used for xterm-256 colors.
string SGR_TEXT_COLORLESS = "39"; /// ditto

	/**
	 * Same as the SGR_TEXT_* codes above, except that these change the color of
	 * the background behind the text rather than the color of the text itself.
	 **/
string SGR_BG_BLACK = "40";
string SGR_BG_RED = "41"; /// ditto
string SGR_BG_GREEN = "42"; /// ditto
string SGR_BG_YELLOW = "43"; /// ditto
string SGR_BG_BLUE = "44"; /// ditto
string SGR_BG_MAGENTA = "45"; /// ditto
string SGR_BG_CYAN = "46"; /// ditto
string SGR_BG_WHITE = "47"; /// ditto
string SGR_BG_COLORLESS = "49"; /// ditto

string SGR_TEXT_256_COLOR = "38" ~ SGR_SEPARATOR ~ "5";
string SGR_BG_256_COLOR = "48" ~ SGR_SEPARATOR ~ "5";

	/**
	 * Makes all subsequently-output text bolder and/or brighter than normal.
	 *
	 * Use SGR_NO_BOLD to turn off boldness/brightness.
	 *
	 * Examples:
	 * ----
	 * writeln(CSI, SGR_BOLD, SGR_TERMINATOR, "This text will appear bold.");
	 * ----
	 **/
string SGR_BOLD = "1";
string SGR_NO_BOLD = "22"; /// ditto

	/**
	 * Makes all subsequently-output text blink indefinitely.
	 * 
	 * Only the text itself blinks; the background behind it remains constant.
	 * Sections of text output with this parameter always blink in-sync with each other.
	 *
	 * Use SGR_NO_BLINK to turn blinking back off.
	 *
	 * Examples:
	 * ----
	 * writeln(CSI, SGR_BLINK, SGR_TERMINATOR, "This text will blink.");
	 * ----
	 **/
string SGR_BLINK = "5";
string SGR_NO_BLINK = "25"; /// ditto

	/**
	 * Underlines all subsequently-output text.
	 *
	 * Use SGR_NO_UNDERLINE to turn underlining back off.
	 *
	 * ----
	 * writeln(CSI, SGR_UNDERLINE, SGR_TERMINATOR, "This text will appear underlined.");
	 * ----
	 **/
string SGR_UNDERLINE = "4";
string SGR_NO_UNDERLINE = "24"; /// ditto

	/**
	 * Used to separate multiple codes introduced by a single CSI and terminated
	 * by a single SGR_TERMINATOR.
	 *
	 * Examples:
	 * ----
	 * // The text "Hello, world," as well as any text that's output
	 * // afterwards, will appear bolded as well as green.
	 * writeln(CSI, SGR_TEXT_GREEN, SGR_SEPARATOR, SGR_BOLD, SGR_TERMINATOR, "Hello, world!");
	 * ----
	 **/
string SGR_SEPARATOR = ";";

	/**
	 * Resets the text's appearance to a clean slate, without any special
	 * formatting applied.
	 *
	 * In practice, this is equivalent to using SGR_TEXT_COLORLESS,
	 * SGR_BACKGROUND_COLORLESS, SGR_NO_BOLD, etc. all at once.
	 *
	 * Examples:
	 * ----
	 * writeln(CSI, SGR_TEXT_RED, SGR_TERMINATOR, "This line of text will be red.");
	 * writeln("This will still be red.");
	 * writeln(CSI, SGR_RESET, SGR_TERMINATOR, "This will be the default color again.");
	 * ----
	 **/
string SGR_RESET = "0";
