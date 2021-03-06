//
//  TextToSpeech.m
//  TextToSpeech
//
//  Created by Anton Krasovsky on 27/09/2016.
//  Copyright © 2016 Anton Krasovsky. All rights reserved.
//

#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>
#import "TextToSpeech.h"

static TextToSpeech *_singleTon;
static NSObject <TextToSpeechDelegate>*_textToSpeechDelegate;

@implementation TextToSpeech

@synthesize bridge = _bridge;

+(TextToSpeech *)getInstance
{
    return _singleTon;
}

+(void)registerDelegate:(NSObject <TextToSpeechDelegate> *)delegate
{
    _textToSpeechDelegate = delegate;
}

-(void) pause
{
    if ([_synthesizer isSpeaking]) {
        [_synthesizer pauseSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }
}

-(void) resume
{
    if ([_synthesizer isPaused]) {
        [_synthesizer continueSpeaking];
    }
}

-(void) toggle
{
    [_synthesizer isPaused] ? [self resume] : [self pause];
}


RCT_EXPORT_MODULE()

-(NSArray<NSString *> *)supportedEvents
{
    return @[@"tts-start", @"tts-finish", @"tts-pause", @"tts-resume", @"tts-progress", @"tts-cancel"];
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        _synthesizer = [AVSpeechSynthesizer new];
        _synthesizer.delegate = self;
        _singleTon = self;
    }

    return self;
}

RCT_EXPORT_METHOD(speak:(NSString *)text
                  voice:(NSString *)voice
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    if(!text) {
        reject(@"no_text", @"No text to speak", nil);
        return;
    }

    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:text];

    if(voice) {
        utterance.voice = [AVSpeechSynthesisVoice voiceWithIdentifier:voice];
    } else if (_defaultVoice) {
        utterance.voice = _defaultVoice;
    }

    [_textToSpeechDelegate willBeginSpeakingWithOptions:nil];

    [self.synthesizer speakUtterance:utterance];
    resolve([NSNumber numberWithUnsignedLong:utterance.hash]);
}


RCT_EXPORT_METHOD(speakWithOptions:(NSString *)text
                  options:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    if(!text) {
        reject(@"no_text", @"No text to speak", nil);
        return;
    }

    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:text];

    if (options) {
        if(options[@"voiceId"]) {
            utterance.voice = [AVSpeechSynthesisVoice voiceWithIdentifier:options[@"voiceId"]];
        } else if (_defaultVoice) {
            utterance.voice = _defaultVoice;
        }

        if (options[@"rate"]) {
            utterance.rate = [options[@"rate"] floatValue];
        }
    }

    [_textToSpeechDelegate willBeginSpeakingWithOptions:options];

    [self.synthesizer speakUtterance:utterance];
    resolve([NSNumber numberWithUnsignedLong:utterance.hash]);
}

RCT_EXPORT_METHOD(stop:(BOOL *)onWordBoundary resolve:(RCTPromiseResolveBlock)resolve reject:(__unused RCTPromiseRejectBlock)reject)
{
    AVSpeechBoundary *boundary;

    if(onWordBoundary) {
        boundary = AVSpeechBoundaryWord;
    } else {
        boundary = AVSpeechBoundaryImmediate;
    }

    BOOL *stopped = [self.synthesizer stopSpeakingAtBoundary:boundary];

    resolve([NSNumber numberWithBool:stopped]);
}

RCT_EXPORT_METHOD(pause:(BOOL *)onWordBoundary resolve:(RCTPromiseResolveBlock)resolve reject:(__unused RCTPromiseRejectBlock)reject)
{
    AVSpeechBoundary *boundary;

    if(onWordBoundary) {
        boundary = AVSpeechBoundaryWord;
    } else {
        boundary = AVSpeechBoundaryImmediate;
    }

    BOOL *paused = [self.synthesizer pauseSpeakingAtBoundary:boundary];

    resolve([NSNumber numberWithBool:paused]);
}

RCT_EXPORT_METHOD(resume:(RCTPromiseResolveBlock)resolve reject:(__unused RCTPromiseRejectBlock)reject)
{
    BOOL *continued = [self.synthesizer continueSpeaking];

    resolve([NSNumber numberWithBool:continued]);
}

RCT_EXPORT_METHOD(setDefaultLanguage:(NSString *)language
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:language];

    if(voice) {
        _defaultVoice = voice;
        resolve(@"success");
    } else {
        reject(@"not_found", @"Language not found", nil);
    }
}

RCT_EXPORT_METHOD(setDefaultVoice:(NSString *)identifier
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithIdentifier:identifier];

    if(voice) {
        _defaultVoice = voice;
        resolve(@"success");
    } else {
        reject(@"not_found", @"Voice not found", nil);
    }
}

RCT_EXPORT_METHOD(voices:(RCTPromiseResolveBlock)resolve
                  reject:(__unused RCTPromiseRejectBlock)reject)
{
    NSMutableArray *voices = [NSMutableArray new];

    for (AVSpeechSynthesisVoice *voice in [AVSpeechSynthesisVoice speechVoices]) {
        [voices addObject:@{@"id": voice.identifier, @"name": voice.name, @"language": voice.language}];
    }

    resolve(voices);
}

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance
{
    [self sendEventWithName:@"tts-start" body:[NSNumber numberWithUnsignedLong:utterance.hash]];
}

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
    [self sendEventWithName:@"tts-finish" body:[NSNumber numberWithUnsignedLong:utterance.hash]];
}

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didPauseSpeechUtterance:(AVSpeechUtterance *)utterance
{
    [self sendEventWithName:@"tts-pause" body:[NSNumber numberWithUnsignedLong:utterance.hash]];
}

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didContinueSpeechUtterance:(AVSpeechUtterance *)utterance
{
    [self sendEventWithName:@"tts-resume" body:[NSNumber numberWithUnsignedLong:utterance.hash]];
}

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer willSpeakRangeOfSpeechString:(NSRange)characterRange utterance:(AVSpeechUtterance *)utterance
{
    [self sendEventWithName:@"tts-progress"
                       body:@{@"location": [NSNumber numberWithUnsignedLong:characterRange.location],
                              @"length": [NSNumber numberWithUnsignedLong:characterRange.length],
                              @"utterance": [NSNumber numberWithUnsignedLong:utterance.hash]}];
}

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance
{
    [self sendEventWithName:@"tts-cancel" body:[NSNumber numberWithUnsignedLong:utterance.hash]];
}

@end
