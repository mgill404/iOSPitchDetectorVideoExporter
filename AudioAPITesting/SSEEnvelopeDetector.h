//
//  SSEEnvelopeDetector.h
//  AudioAPITesting
//
//  Edited by Mark Gill on 6/15/15.
//  Credited to Will Pirkle www.willpirkle.com
//

#ifndef __AudioAPITesting__SSEEnvelopeDetector__
#define __AudioAPITesting__SSEEnvelopeDetector__

#include <stdio.h>

const float DIGITAL_TC = -2.0; // log(1%)
const float ANALOG_TC = -0.43533393574791066201247090699309; // (log(36.7%)
const float METER_UPDATE_INTERVAL_MSEC = 15.0;
const float METER_MIN_DB = -60.0;

#define FLT_EPSILON_PLUS      1.192092896e-07         /* smallest such that 1.0+FLT_EPSILON != 1.0 */
#define FLT_EPSILON_MINUS    -1.192092896e-07         /* smallest such that 1.0-FLT_EPSILON != 1.0 */
#define FLT_MIN_PLUS          1.175494351e-38         /* min positive value */
#define FLT_MIN_MINUS        -1.175494351e-38         /* min negative value */

typedef unsigned int UINT;

class SSEEnvelopeDetector
{
public:
    SSEEnvelopeDetector(void);
    ~SSEEnvelopeDetector(void);
    
    
    // Call the Init Function to initialize and setup all at once; this can be called as many times
    // as you want
    void init(float samplerate, float attack_in_ms, float release_in_ms, bool bAnalogTC, UINT uDetect, bool bLogDetector);
    
    // these functions allow you to change modes and attack/release one at a time during
    // realtime operation
    void setTCModeAnalog(bool bAnalogTC);
    // THEN do these after init
    void setAttackTime(float attack_in_ms);
    void setReleaseTime(float release_in_ms);
    
    // Use these "codes"
    // DETECT PEAK   = 0
    // DETECT MS	 = 1
    // DETECT RMS	 = 2
    //
    void setDetectMode(UINT uDetect) {m_uDetectMode = uDetect;}
    
    void setSampleRate(float f) {m_fSampleRate = f;}
    
    void setLogDetect(bool b) {m_bLogDetector = b;}
    
    // call this to detect; it returns the peak ms or rms value at that instant
    float detect(float& fInput);
    
    float detect(float* fInput, int length);
    
    // call this from your prepareForPlay() function each time to reset the detector
    void prepareForPlay();
    
protected:
    int  m_nSample;
    float m_fAttackTime;
    float m_fReleaseTime;
    float m_fAttackTime_mSec;
    float m_fReleaseTime_mSec;
    float m_fSampleRate;
    float m_fEnvelope;
    UINT  m_uDetectMode;
    bool  m_bAnalogTC;
    bool  m_bLogDetector;
};

#endif /* defined(__AudioAPITesting__SSEEnvelopeDetector__) */
