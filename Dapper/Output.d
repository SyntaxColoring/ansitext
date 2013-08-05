
module Dapper.Output;

import Dapper.Codes;
import std.conv;
import std.stdio;

private
{
		/**
		 * Functor for streamlining the implementation of formatters and their
		 * ability to nest.
		 * 
		 * NestableFormatters are initialized from within the library with an SGR parameter.
		 * Afterwards, when they are called as functions in calling code, they apply
		 * that SGR code to each of their arguments in such a way that works with nesting.
		 *
		 * This simplifies the implementation of the library.  Rather than having discrete
		 * functions for making text colored, bold, underlined, etc., all the important logic
		 * for formatting can live here in one place.
		 **/
	struct NestableFormatter
	{
		private const string SGRParameter;
		
		@disable this();
		this(string SGRParameter) { this.SGRParameter = SGRParameter; }
		
		string opCall(Types...)(Types ContainedArguments) const
		{
			string CompiledResult;
			
			foreach (Argument; ContainedArguments)
			{
				CompiledResult ~= CSI ~ SGRParameter ~ SGR_TERMINATOR;
				
				// Using to!string emulates writeln's flexibility with the types of its arguments.
				CompiledResult ~= to!string(Argument);
			}

			return CompiledResult ~ CSI ~ SGR_RESET ~ SGR_TERMINATOR;
		}
	}
	
	template NestableCustomColorFormatter(string SGRParameter)
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
				import std.math;
				
				const uint IntegralRed = cast(uint)(Red * 6 + 0.5);
				const uint IntegralGreen = cast(uint)(Green * 6 + 0.5);
				const uint IntegralBlue = cast(uint)(Blue * 6 + 0.5);
				
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
	auto Black       = NestableFormatter(SGR_TEXT_BLACK);
	auto Red         = NestableFormatter(SGR_TEXT_RED);
	auto Green       = NestableFormatter(SGR_TEXT_GREEN);
	auto Yellow      = NestableFormatter(SGR_TEXT_YELLOW);
	auto Blue        = NestableFormatter(SGR_TEXT_BLUE);
	auto Magenta     = NestableFormatter(SGR_TEXT_MAGENTA);
	auto Cyan        = NestableFormatter(SGR_TEXT_CYAN);
	auto White       = NestableFormatter(SGR_TEXT_WHITE);
	auto Colorless   = NestableFormatter(SGR_TEXT_COLORLESS);
	
	auto BlackBG     = NestableFormatter(SGR_BG_RED);
	auto RedBG       = NestableFormatter(SGR_BG_RED);
	auto GreenBG     = NestableFormatter(SGR_BG_GREEN);
	auto YellowBG    = NestableFormatter(SGR_BG_YELLOW);
	auto BlueBG      = NestableFormatter(SGR_BG_BLUE);
	auto MagentaBG   = NestableFormatter(SGR_BG_MAGENTA);
	auto CyanBG      = NestableFormatter(SGR_BG_CYAN);
	auto WhiteBG     = NestableFormatter(SGR_BG_WHITE);
	auto ColorlessBG = NestableFormatter(SGR_BG_COLORLESS);
	
	auto Bold        = NestableFormatter(SGR_BOLD);
	auto NoBold      = NestableFormatter(SGR_NO_BOLD);
	
	auto Blink       = NestableFormatter(SGR_BLINK);
	auto NoBlink     = NestableFormatter(SGR_NO_BLINK);
	
	auto Underline   = NestableFormatter(SGR_UNDERLINE);
	auto NoUnderline = NestableFormatter(SGR_NO_UNDERLINE);
	
	alias NestableCustomColorFormatter!SGR_TEXT_256_COLOR CustomColor;
	alias NestableCustomColorFormatter!SGR_BG_256_COLOR CustomColorBG;
}
