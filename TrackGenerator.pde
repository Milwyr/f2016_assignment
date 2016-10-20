class TrackGenerator implements Runnable {

    private Track track; // MIDI track
    private int sound;
    private float vol;
    private int[] pp;
    private float stereoPosition;
    private int startTime;
    private int endTime;
    private float tickDuration;
    private int samplingRate;
    private AudioSamples trackSamples; // Samples generated by this track

    // Constructor
    TrackGenerator(Track track, int sound, float vol, int[] pp, float stereoPosition, int startTime, int endTime, float tickDuration, int samplingRate) {
        this.track = track;
        this.sound = sound;
        this.vol = vol;
        this.pp = new int[pp.length];
        this.stereoPosition = stereoPosition;
        for(int i = 0; i < pp.length; ++i) {
            this.pp[i] = pp[i];
        }
        this.startTime = startTime;
        this.endTime = endTime;
        this.tickDuration = tickDuration;
        this.samplingRate = samplingRate;

        this.trackSamples = new AudioSamples(endTime - startTime, samplingRate);
    }

    public void run() {
        // Read every MIDI event and handle all note on
        for(int i = 0; i < track.size(); ++i) {
            MidiEvent e = track.get(i);
            MidiMessage m = e.getMessage();
            if(m instanceof ShortMessage) { // Only ShortMessage are useful
                ShortMessage sm = (ShortMessage)(m);

                // Find all note on
                if(sm.getCommand() == ShortMessage.NOTE_ON && sm.getData2() != 0) {
                    float start = e.getTick() * tickDuration;

                    // Skip this event if it is not within the targeted time range
                    if(start < startTime || start > endTime) continue;

                    // Read the details of the note on command
                    int channel = sm.getChannel();
                    int pitch = sm.getData1();
                    float frequency = MIDIPitchToFreq(pitch);
                    float amp = sm.getData2() / 127.0;
                    float duration = 0;

                    // Search for the corresponding note off event
                    for(int j = i + 1; j < track.size(); ++j) {
                        MidiEvent e2 = track.get(j);
                        MidiMessage m2 = e2.getMessage();
                        if(m2 instanceof ShortMessage) {
                            ShortMessage sm2 = (ShortMessage)(m2);

                            // It could be a "note off" or a "note on with velocity 0"
                            if(sm2.getCommand() == ShortMessage.NOTE_OFF && sm2.getChannel() == channel && sm2.getData1() == pitch) {
                                duration = e2.getTick() * tickDuration - start;
                                break;
                            } else if(sm2.getCommand() == ShortMessage.NOTE_ON && int(sm2.getData2()) == 0 &&
                                      sm2.getChannel() == channel && sm2.getData1() == pitch) {
                                duration = e2.getTick() * tickDuration - start;
                                break;
                            }
                        }
                    }

                    // Ignore the note on if we cannot find the matching note off
                    if(duration > 0) {
                        // Create a new SoundGenerator with parameters of this note
                        SoundGenerator sg = new SoundGenerator(sound, amp * vol, frequency, duration, samplingRate);
                        AudioSamples ss = sg.generateSound();
                        for(int k = 0; k < pp.length; ++ k) {
                            if(pp[k] > 1) ss.applyPostProcessing(pp[k]); // Apply post processings, if any
                        }
                        trackSamples.add(ss, 0.5, start, duration); // Add the generted sound to the track samples
                    }
                }
            }
        }

        musicSamples.add(trackSamples, stereoPosition, startTime); // Add the track samples to the music samples
    }

    // This function convert MIDI pitch to frequency
    private float MIDIPitchToFreq(int MIDIPitch) {
        // float temp = 256.0;
        double exponent = (MIDIPitch - 49d) / 12d;
        double frequency = 440 * (Math.pow(2d, exponent));
        
        System.out.println("Note: " + MIDIPitch + "; Frequency: " + String.format("%.2f", frequency));
        return (float) frequency;
    }
}