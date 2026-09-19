package koto

// adapted from gflw
Keys :: enum  {
	/* Named printable keys */
	SPACE         = 32,
	APOSTROPHE    = 39,  /* ' */
	COMMA         = 44,  /* , */
	MINUS         = 45,  /* - */
	PERIOD        = 46,  /* . */
	SLASH         = 47,  /* / */
	SEMICOLON     = 59,  /* ; */
	EQUAL         = 61,  /* = */
	LEFT_BRACKET  = 91,  /* [ */
	BACKSLASH     = 92,  /* \ */
	RIGHT_BRACKET = 93,  /* ] */
	GRAVE_ACCENT  = 96,  /* ` */
	WORLD_1       = 161, /* non-US #1, */
	WORLD_2       = 162, /* non-US #2, */
	
	/* Alphanumeric characters */
	N_0 = 48,
	N_1 = 49,
	N_2 = 50,
	N_3 = 51,
	N_4 = 52,
	N_5 = 53,
	N_6 = 54,
	N_7 = 55,
	N_8 = 56,
	N_9 = 57,
	
	A = 65,
	B = 66,
	C = 67,
	D = 68,
	E = 69,
	F = 70,
	G = 71,
	H = 72,
	I = 73,
	J = 74,
	K = 75,
	L = 76,
	M = 77,
	N = 78,
	O = 79,
	P = 80,
	Q = 81,
	R = 82,
	S = 83,
	T = 84,
	U = 85,
	V = 86,
	W = 87,
	X = 88,
	Y = 89,
	Z = 90,
	
	
	/** Function keys **/
	
	/* Named non-printable keys */
	F_ESCAPE       = 256,
	F_ENTER        = 257,
	F_TAB          = 258,
	F_BACKSPACE    = 259,
	F_INSERT       = 260,
	F_DELETE       = 261,
	A_LEFT         = 263,
	A_DOWN         = 264,
	A_UP           = 265,
	A_RIGHT        = 262,
	F_PAGE_UP      = 266,
	F_PAGE_DOWN    = 267,
	F_HOME         = 268,
	F_END          = 269,
	F_CAPS_LOCK    = 280,
	F_SCROLL_LOCK  = 281,
	F_NUM_LOCK     = 282,
	F_PRINT_SCREEN = 283,
	F_PAUSE        = 284,
	
	/* Function keys */
	F1  = 290,
	F2  = 291,
	F3  = 292,
	F4  = 293,
	F5  = 294,
	F6  = 295,
	F7  = 296,
	F8  = 297,
	F9  = 298,
	F10 = 299,
	F11 = 300,
	F12 = 301,
	F13 = 302,
	F14 = 303,
	F15 = 304,
	F16 = 305,
	F17 = 306,
	F18 = 307,
	F19 = 308,
	F20 = 309,
	F21 = 310,
	F22 = 311,
	F23 = 312,
	F24 = 313,
	F25 = 314,
	
	/* Keypad numbers */
	KP_0 = 320,
	KP_1 = 321,
	KP_2 = 322,
	KP_3 = 323,
	KP_4 = 324,
	KP_5 = 325,
	KP_6 = 326,
	KP_7 = 327,
	KP_8 = 328,
	KP_9 = 329,
	
	/* Keypad named function keys */
	KP_DECIMAL  = 330,
	KP_DIVIDE   = 331,
	KP_MULTIPLY = 332,
	KP_SUBTRACT = 333,
	KP_ADD      = 334,
	KP_ENTER    = 335,
	KP_EQUAL    = 336,
	
	/* Modifier keys */
	M_LEFT_SHIFT    = 340,
	M_LEFT_CONTROL  = 341,
	M_LEFT_ALT      = 342,
	M_LEFT_SUPER    = 343,
	M_RIGHT_SHIFT   = 344,
	M_RIGHT_CONTROL = 345,
	M_RIGHT_ALT     = 346,
	M_RIGHT_SUPER   = 347,
	M_MENU          = 348,
}
