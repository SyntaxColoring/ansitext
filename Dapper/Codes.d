	/**
	 * Provides low-level mappings to make it easier for you to form common
	 * ANSI escape codes by yourself.
	 * 
	 * Most people should use $(DPMODULE Output) instead of this module, since it
	 * provides all the same functionality at a higher, more convenient level of abstraction.
	 * 
	 * 
	 * Escape_Code_Basics:
	 * ANSI escape codes are special sequences of text that give instructions to
	 * the terminal when they are output.  They're commonly used to colorize text
	 * and achieve other formatting effects.
	 *
	 * Every ANSI escape code supported by Dapper begins with $(MREF CSI) and ends with a terminator
	 * such as $(MREF MOVE_CURSOR_TERMINATOR).  Depending on the terminator, there is almost
	 * always also some number of integer parameters in the middle.  Multiple
	 * parameters are separated by $(MREF SEPARATOR).
	 *
	 * Continuing with the $(MREF MOVE_CURSOR_TERMINATOR) example, the following
	 * would move the cursor to the top-middle of a typical terminal window
	 * (row 1, column 40):
	 
	 * ---
	 * writeln(CSI, 1, SEPARATOR, 40, MOVE_CURSOR_TERMINATOR);
	 * ---
	 * 
	 * Select_Graphic_Rendition_Codes:
	 * SGR is a large subset of ANSI escape codes that changes the appearance
	 * of text (underlining, changing color, etc.).
	 *
	 * SGR codes all use the terminator $(MREF SGR_TERMINATOR) and generally have
	 * a single parameter.  That parameter decides what effect will be applied to the text.
	 * It is possible to use multiple parameters at once - see the example for
	 * $(MREF SEPARATOR).
	 *
	 * $(I When an SGR code is activated, it remains so until explicitly deactivated) -
	 * even after your program stops running!  The $(DPMODULE Output) module
	 * takes care of this for you, but you'll need to clean up manually with
	 * $(MREF SGR_RESET) if you use the codes from here.
	 * 
	 * 
	 * Standards:
	 * ANSI escape codes are somewhat ill-defined.  Every terminal emulator has its
	 * quirks, and many codes simply don't work except in rare cases.  This module
	 * tries to limit its support to the most common codes.  Even though this necessarily
	 * omits some codes that may be useful, it also means that the codes included
	 * here can be relied on working in most environments.
	 * 
	 * 
	 * See_Also:
	 * Dapper.Format, $(HTTP en.wikipedia.org/wiki/ANSI_escape_code)
	 **/
module Dapper.Codes;

immutable:

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
