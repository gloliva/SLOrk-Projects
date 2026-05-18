public class LogMode {
    0 => static int ALL;
    1 => static int NO_DEBUG;
    2 => static int NO_ERROR;
    3 => static int NONE;
}


public class Log {
    static int MODE;

    fun static void print(string s) {
        Log.print(s, true);
    }

    fun static void print(string s, int nl) {
        if (Log.MODE == LogMode.NONE) return;

        chout <= s;
        if (nl) chout <= IO.nl();
    }

    fun static void error(string e) {
        Log.error(e, true);
    }

    fun static void error(string e, int nl) {
        if (Log.MODE == LogMode.NONE || Log.MODE == LogMode.NO_ERROR) return;

        cherr <= "ERROR: " <= e;
        if (nl) cherr <= IO.nl();
    }

    fun static void debug(string s) {
        Log.debug(s, true);
    }

    fun static void debug(string s, int nl) {
        if (Log.MODE > LogMode.ALL) return;

        chout <= "DEBUG: " <= s;
        if (nl) chout <= IO.nl();
    }

    fun static void setMode(int mode) {
        mode => Log.MODE;
    }
}
