# sub

**sub** is a scripting toolkit made for automating various subbing tasks.
It can help with premux creation, release muxing, CRC32 hashing, torrent creation, and can also help make life easy for projects with multiple subtitle tracks.

## How to use it

* Before you start, you should make sure you have [xdelta3](http://xdelta.org/) and [mkvtoolnix](https://www.bunkus.org/videotools/mkvtoolnix/) available in your PATH. (Look up enviroment variables if you're unsure what that is.)
* First, install [node.js](https://nodejs.org/) or [io.js](https://iojs.org). Either should work, but if in doubt go with Node.
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