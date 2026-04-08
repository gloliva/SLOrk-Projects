public class Sequence {
    int _notes[];

    fun @construct(int initNotes[]) {
        initNotes @=> this._notes;
    }

    fun void notes(int n[]) {
        n @=> this._notes;
    }

    fun int[] notes() {
        return this._notes;
    }

    fun int size() {
        if (this._notes != null) return this._notes.size();

        return 0;
    }
}
