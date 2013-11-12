sample-multi-shotifier
======================

hack which expands your traditional hardware/software samplers using many-samples-in-one-sample (poor man's soundfont)

### Introduction ###

Breath new life into your hardware/software samplers by using multishots + start-sample-offset-parameter. Combine all samples to one wavefile, and expand your 1-sample-per-midichannel device into a xxx-sample-per-midichannel device. For example, on the electribe ESX one can have 127 samples on one drumtrack using this utility.
(Only requirement is having SOX utilities installed)

<img src="http://www.zimagez.com/full/cbeb14ba4786a5c6329a618ec91320d4556edab6378d82906924c0fb25bf0a9d2353c0c2c4e1fd0bd5f293e42232e60a7ff3f6859b7a1c80.php"/>

<img src="http://www.zimagez.com/full/21f7122ee557a157329a618ec91320d4faab8d24e80693de6924c0fb25bf0a9d2353c0c2c4e1fd0bd5f293e42232e60aba168cc19324ea02.php"/>

### How it works ###

This is a *directorybased* sample-utility which can glue samplefiles together into one samplefile. This file can be used in old/new hardware/software samplers. This only works well if your sampler supports setting the samplestart-offset-parameter on-the-fly. For example, your sample startposition-knob goes from 0..127, then you can navigate thru 127 samples if you generate a sample which contains 127 samples (with the same length..hence the trim-feature). Hope this makes sense, if not, just try it and you'll get the idea :)

### Requirements ###

following things are usually installed on any linux system:

* nc (netcat)
* a browser
* bash

### Credits ###

* made with [bashwapp](https://github.com/coderofsalvation/bashwapp)
