# sub

**sub** is a scripting toolkit made for automating various subbing tasks.
It can help with premux creation, release muxing, CRC32 hashing, torrent creation, and can also help make life easy for projects with multiple subtitle tracks.

## How to use it

* Before you start, you should make sure you have [xdelta3](http://xdelta.org/) and [mkvtoolnix](https://www.bunkus.org/videotools/mkvtoolnix/) available in your PATH. (Look up enviroment variables if you're unsure what that is.)
* First, install [Node.js](https://nodejs.org/).
* Next, you need to pop open command line and install [LiveScript](http://livescript.net/) globally by running `npm install -g LiveScript`
* Now, you should have some sort of work folder that hosts all your project folders. Let's say it's called Work, so you would have a folder setup like so:
```
  /Work/
  /Work/Show/
  /Work/ShowTwo/
  /Work/AnotherShow/
```
* What you need to do is copy the `package.json` file from this repository to Work (so you have it at `/Work/package.json`), then navigate to this folder via command line and run `npm install`. This will install the modules required by sub into `/Work/node_modules/`.
* Next up, copy `sub.ls` to a project folder, eg. `/Work/Show/sub.ls`
* Now, open the file, go through it and edit in your project details.
* After your subfile is set up, you use it via command line by running commands like the following:
```
$ lsc sub swaps 01
$ lsc sub mux 02-04
$ lsc sub premux 03-05 07
$ lsc sub v2 03
```
* To use **sub** with another project, simply copy `sub.ls` to its folder and edit accordingly.

## Making multiple subtitle tracks

**sub** enables you to have a single master ASS script that can be used to generate multiple scripts for the actual episode with the use of a swapping syntax. Usage of this syntax is fairly simple. Let's say you have the following lines:
```
What is it, Haruka{**-chan}?
Nothing, {*}Dad{*Otou-san}!
```
For the swapped version, it will turn these lines into:
```
What is it, Haruka{*}-chan{*}?
Nothing, {*}Otou-san{*Dad}!
```
By default, the swapping will be only performed on lines with styles that
start with either "Default" or "Alternative". You can also make it work on
additional styles by passing a regular expression to the `subswap` function. Additional instructions can be found in the file itself.

There is also a way to swap whether a line is a comment or not. Simply set the line's effect to `***`. This is mainly useful if you need to have multiple versions of a typeset sign - you can have one uncommented version as the default, another commented one with the necessary changes, then set the Effect for both to `***` and they will be enabled and disabled accordingly for the appropriate subtitle tracks. Pseudo-ASS example:
```
    Dialogue: {\an9}Oh no!
*** Dialogue: {\an7}Haruka!
*** Comment:  {\an7}Haruka-chan!
    Dialogue: {\an1}Yet Another Sign
```

## Filename Scheme

Using **sub** assumes that you are using a specific kind of filenaming scheme
for your project files. It's probably best to demonstrate by example. Any files marked with `*` are used by the script, so they're the important bits as far as usage is concerned.

Note: You will never need to touch the generated language-tagged script files yourself. The only thing that matters for work is the master script.

```
## Common Files ##
Show.00.premux.720p.mkv *  - premux files
Show.00.premux.720p.ass *  - master scripts
Show.00.fonts.zip *        - all episode fonts in a zip
Show.00.chapters.xml *     - chapter files
Show.00.release.lang.ass * - subswap-generated scripts
Show.00.keyframes.txt      - keyframes
Show.00.wraw.720p.mkv      - wraws

## Encoder Files ##
Show.00.CR.1080p.mkv *      - (softsubbed) simulcast rips
Show.00/0.part.mkv *        - encodes done in multiple parts
Show.00.mux.video.mkv *     - final video for the episode
Show.00.mux.audio.mka *     - final audio for the episode
Show.00.avs                 - the avs file
Show.00.chapters.qpfile     - self-explanatory
Show.00.work.keyframes.avs  - keyframe generation avs
Show.00.work.video-720p.avs - wraw video encoding avs
```
The `Show.00` part above is what's called `prefix` in the code definitions of **sub**'s commands. If you want to change that, you'll need to edit all the prefix definitions at the start of the command functions accordingly. For example, if you had all the episodes in their own subfolders, you'd change the prefix to `"#num/#name.#num"` and then you would run the script from the
parent directory (so that you only need one copy of it). To demonstrate:
```
/Work/Show/
/Work/Show/sub.ls
/Work/Show/01/Show.01.premux.720p.mkv
/Work/Show/01/Show.01.premux.720p.ass
... etc ...
Run commands from /Work/Show/ where sub.ls is located
```