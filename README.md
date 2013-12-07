sample-multi-shotifier
======================

Create perfectly aligned multisample output.
A Hack which expands your traditional hardware/software samplers using many-samples-in-one-sample (poor man's soundfont).

<img src="https://raw.github.com/coderofsalvation/sample-multi-shotifier/master/exampleoutput.png"/>

*UPDATE*: added automatic slice detection/cutting support (think drumloops e.g.)
*UPDATE*: added reversed padding option, pad with reversed sample instead of silence 

### Introduction ###

Breath new life into your hardware/software samplers by using multishots + start-sample-offset-parameter. Combine all samples to one wavefile, and expand your 1-sample-per-midichannel device into a xxx-sample-per-midichannel device. For example, on the electribe ESX one can have 128 samples on one drumtrack using this utility.
(Only requirement is having SOX utilities installed)

<img src="https://raw.github.com/coderofsalvation/sample-multi-shotifier/master/html/screenshot.png"/>

### Why? ###

In these days fiddling with hardware samplers can be cumbersome..swapping disks, copying stuff etc.
With this tool you can just 'bake' a subset of your sample collection/directories to one file, and access them all at once on your sampler.

### How it works ###

This is a *directorybased* sample-utility which can glue samplefiles together into one samplefile. This file can be used in old/new hardware/software samplers. This only works well if your sampler supports setting the samplestart-offset-parameter on-the-fly. For example, the startposition-knob on your sampler goes from 0..127. In theory this means you can navigate thru 128 samples if you generate a sample which contains 128 samples (with the same length..hence the trim-feature). Hope this makes sense, if not, check out this sexy ascii art:

    Normally you would load one sample into one sample slot:

    0                                                127
    +-------------------------------------------------+
    | yeeeeeeeeeeeaaaaaaaaaaaaaaaaaaaaaaaaaahhh!!!!!!!|
    +-------------------------------------------------+



    Ok now suppose a sample like this:

    0      1      2      3      4                      127
    +---------------------------------------------------+
    |yeah! |ooh!  |funky!|hello!|    .. (and so on)     | = 128 samples :)
    +---------------------------------------------------+
           ^     ^-- bit of silence, takes up a bit of samplememory 
           |
           +----------------- Assuming your sampler startpositionknob ranges from 0 till 127:
                              If you twist/set your startpositionknob to value 1, 
                              then in theory you'll skip to the next sample


In theory this means you can turn an old dusty hardware sampler with these specifications:

    (st) sample tracks:                                                         11
    (pm) sample possibilities per memoryslot                                    1
    (sm) sample memoryslots:                                                    128      
    (ms) max sequencer steps:                                                   128
    (ps) possibilities of different samples playing per step:     (sm*pm)^st  = 151115727451828646838272 
    (pp) possibilities of different samples playing per pattern:       ps^ms  = big

Into a beast with these specs:
    
    (st) sample tracks:                                                         11
    (pm) sample possibilities per memoryslot                                    128
    (sm) sample memoryslots:                                                    128      
    (ms) max sequencer steps:                                                   128
    (ps) possibilities of different samples playing per step:     (sm*pm)^st  = 22835963083295358096932575511191922182123945984
    (pp) possibilities of different samples playing per pattern:       ps^ms  = HUGE!HUGE!HUGE!

### Pros/Cons ###

* Pros: This gives a totally new dimension to your sampler.
* Cons: it can cost a bit more samplememory since the samples need to be padded properly

The sample-multi-shotifier includes a (non-lossless) pitch-up-feature which can save samplememory, so its up
to you in which area you will suffer samplememory.

### Requirements ###

following things are usually installed on any linux system:

* nc (netcat)
* a browser
* bash
* sox utilities  (14.4.*)

### Credits ###

* made with [bashwapp](https://github.com/coderofsalvation/bashwapp)
