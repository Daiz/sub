/*
  #### sub ####

  A handy-dandy script file for doing various subbing tasks.
  You should read through this whole file and tweak accordingly
  before you actually start using it. A lot of comments are included
  to help you around.

  Besides node.js, LiveScript and the npm packages, usage of this script
  also requires that you have xdelta3 and mkvtoolnix in your PATH.

  Using this assumes that you are using a specific kind of filenaming scheme
  for your project files. It's probably best to demonstrate by example.
  Any files marked with * are used by this script, so they're the
  important bits as far as usage is concerned.

  Note: You will never need to touch the subswap-generated scripts
        manually - the only thing that matters for work is the
        master script.
  
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

  The "Show.00" part above is what's called "prefix" in commands
  defined below. If you want to change that, you'll need to edit
  all the prefix definitions accordingly. For example, if you had
  all the episodes in their own subfolders, you'd change it to
  "#num/#name.#num" and then you would run the script from the
  parent directory (so that you only need one copy of it).

*/

### CONSTANTS ###
# Edit as appropriate for each show.

group = "" # group name used in releases.
irc = ''   # IRC channel info for torrent comment, ie '#channel@irc.rizon.net'
name = ""  # short work name eg. Usagi, Uchouten, etc.
show = ""  # filename eg. Gochuumon wa Usagi Desu ka etc.
title = "" # mkv title name, eg. Is the Order a Rabbit?
episodes = titlify [ # episode titles
  "Episode 1"
  "Episode 2"
  "Etc."
]
langs = { # subtitle track languages and names
  eng: "English"
  enm: "English (JP honorifics)"
}
# For single track shows just have the one you need.
# Note that you'll need to edit the target.mux function below too.
# Instructions can be found at the relevant part.

### REQUIRES ###
# Don't touch these.

require 'shelljs/global'
require! {
  \buffer-crc32
  \cutlass
  \zpad
  \optimist
  \subswap
  \unzip
  \fs
  \nt
}
crc = buffer-crc32
ass = cutlass

### SETUP ###
# Don't touch these either.

# font muxing related stuff
filename = /\/([^\/]+\.(?:ttf|otf|ttc))$/i
ext = /\.(ttf|otf|ttc)$/i

# helper functions
function titlify episodes
  ret = {}
  for title, index in episodes
    key = index + 1
    key = key < 10 and "0#key" or "#key"
    ret[key] = title
  ret

run = (cmd, callback) !->
  cmd .= replace /\r\n|\r|\n/g ' '
  # console.log cmd
  code, output <-! exec cmd, {+async, -silent}
  callback output, code

log = -> console~log ...

extract = (archive, target, next) !->
  if typeof! target == \Function and !next
    next = target
    target = "./" + archive.replace /\.zip$/ ''

  stream = fs.create-read-stream archive .pipe unzip.Extract path: target
  stream.on \close (err) !->
    if err then return next err
    else return next void

# version global - unset by default for regular releases
vx = ""

# command running code
target = {}

cmd = (command, queue) !->
  if queue?length
    next = zpad queue.shift!
    cb = !-> cmd command, queue
    if typeof! next is \String and range = next.match /(\d+)-(\d+)/
      start = parse-int range.1, 10
      end   = parse-int range.2, 10
      pre = [start to end]
      queue = pre.concat queue
      next = zpad queue.shift!
    # console.log next, queue
    target[command] next, cb

set-timeout (!->
  argv = optimist.argv._
  command = argv.shift!
  cmd command, argv
), 0

### COMMANDS ###
# A lot of useful commands are included here by default,
# but you can also expand them with your own ones.
# To do so, simply add a new command like so:
#  
#  target.example = (num, next) !->
#  
#    prefix = "#name.#num"
#  
#    # do stuff here
#  
#    # all commands need to end with this
#    next!
#  
# Pre-defined commands follow below.

## `swaps`
# Pre-processes basic honorifics to swap syntax.
# Can be expanded freely, though you should only
# run this script once per episode script since
# it is NOT idempotent.
target.swaps = (num, next) !->

  prefix = "#name.#num"
  
  main = new ass.Script cat "#prefix.premux.720p.ass"

  for line in main.events

    t = line.text
    t = t
      # the actual swaps are done here with regex replacements
      .replace /\s+/g ' '
      .replace /\b-san\b/g '{**-san}'
      .replace /\b-kun\b/g '{**-kun}'
      .replace /\b-chan\b/g '{**-chan}'
      .replace /\b-sama\b/g '{**-sama}'
      .replace /\b-senpai\b/g '{**-senpai}'
      .replace /\b-sensei\b/g '{**-sensei}'

    # only apply the swaps to lines with styles
    #that begin with Default or Alternative
    if line.style.match /^(?:Default|Alternative)/
      line.text = t

  # write over the old script version with no swaps
  main.to-ass!.to "#prefix.premux.720p.ass"

  next!

## `subs`
# Same as above, but also extracts the script from a softsubbed simulcast rip.
# Also generates a plain text file for easy etherpad copypasting.
target.subs = (num, next) !->

  prefix = "#name.#num"

  # Before running this command for the first time, open up the script
  # from the simulcast rip in Aegisub and look at the styles
  # You should list all dialogue styles from the script here so that
  # any other lines with any other styles will be considered signs
  main-styles =
    "show-main"
    "show-overlap"

  # I rename rips as Show.XX.CR/DAISUKI.1080p.mkv but you can edit this
  # if you don't feel like doing that yourself or use another scheme
  ep = (ls "#prefix.CR.*.mkv")?0
  
  <-! run "mkvextract tracks #ep 2:#prefix.CR.raw.ass"
  
  main = new ass.Script cat "#prefix.CR.raw.ass"

  dialogue = []
  signs = []
  plain = []

  for line in main.events

    t = line.text
    t = t
      .replace /\s+/g ' '
      .replace /\b-san\b/g '{**-san}'
      .replace /\b-kun\b/g '{**-kun}'
      .replace /\b-chan\b/g '{**-chan}'
      .replace /\b-sama\b/g '{**-sama}'
      .replace /\b-senpai\b/g '{**-senpai}'
      .replace /\b-sensei\b/g '{**-sensei}'

      # here we check that the current line
      # has a dialogue style listed above
      if (main-styles.index-of line.style) > -1
        # CR likes to use styles with internal for italics
        # so we can add {\i1} to the beginning of any lines
        # to match up with CR's italics
        if line.style.match /internal/
          t = "{\\i1}" + t
        # same for styles with "top" in the name
        if line.style.match /top/
          t = "{\\an8}" + t
          # I generally have a style called DefaultTop
          # to have 5px (at 720p) lower vertical margin
          line.style = "DefaultTop"
        else
          line.style = "Default"
        line.text = t
        dialogue.push line

      # lines that are considered sings will be preceded
      # with a {TS XX:XX} timestamp and put at the top
      # of the file for maximum pad convenience
      else
        ts = line.get-start-time!
        ts-prefix = '{' + "TS #{zpad ts.mm}:#{zpad ts.ss}" + '}'
        # t = t.replace /\{\\.*?\}/g ''
        line.text = ts-prefix + t
        line.style = "Sign"
        signs.push line

  main.events = signs.concat dialogue

  for line in main.events
    plain.push line.text

  main.header {
    "Title": "[#group] #show - #num"
    "PlayResX": 1280
    "PlayResY": 720
    "YCbCr Matrix": "TV.709"
  }

  main.to-ass!.to "#prefix.CR.ass"
  plain.join "\r\n" .to "#prefix.CR.txt"

  next!

## `video`
# This and the following commands are mainly for encoder usage.
# `video` will mux a video encoded in multiple parts # into
# a single "Show.XX.mux.video.mkv" file.
target.video = (num, next) !->

  prefix = "#name.#num"

  parts = ls "./#prefix/*.part.mkv"
  first-part = parts.shift!

  cmd = """
  mkvmerge -o "#prefix.mux.video.mkv"
  --disable-track-statistics-tags
  "#first-part"

  """

  for part in parts
    cmd += """
    "+#part"

    """

  console.log "Muxing video for episode #num..."

  <-! run cmd

  next!

## `video-skip`
# This simply skips the video muxing
# if it has already been ran before.
target.video-skip = (num, next) !->

  if test \-e "#name.#num.mux.video.mkv" then return next!

  <-! target.video num

  next!

## `premux`
# This will do the actual premux.
# You can mux chapters in at this point already,
# but you can also leave that for the actual mux
# by moving the --chapters "#prefix.chapters.xml"
# part to the main muxing command below.
target.premux = (num, next) !->

  prefix = "#name.#num"

  <-! target.video-skip num

  cmd = """
  mkvmerge -o "#prefix.premux.720p.mkv"
  --disable-track-statistics-tags
  --language "0:und"
  --track-name "0:H.264 (10-bit)"
  --compression "0:none"
  -d 0 -A -S -T --no-global-tags --no-chapters
  "(" "#prefix.mux.video.mkv" ")"
  --language "0:jpn"
  --track-name "0:Japanese 2.0 AAC"
  --compression "0:none"
  -a 0 -D -S -T --no-global-tags --no-chapters
  "(" "#prefix.mux.audio.mka" ")"
  --chapters "#prefix.chapters.xml"
  """

  console.log "Premuxing episode #num..."

  <-! run cmd

  next!

# Encoding-related commands end here.

## `mux`
# This is the main muxing command.
# Used for QC and release muxing.
target.mux = (num, next) !->

  prefix = "#name.#num"

  main = new ass.Script cat "#prefix.premux.720p.ass"

  # do sort by time here so you can keep your master script nicely organized
  main.sort!

  # this is where the magic happens, * indicates the swaps to perform
  scripts = subswap main, '*'

  for lang, script of scripts
    script.to-ass!.to "#prefix.release.#lang.ass"

  # if you're not going to use multiple scripts,
  # you can simply simply comment out the above
  # and uncomment the following line and adjust
  # the lang part to what you defined in the
  # langs constant up at the top.
  /* main.to-ass!.to "#prefix.release.lang.ass" */

  #  unzip fonts
  if test \-e "./#prefix.fonts/" then rm \-Rf "./#prefix.fonts/*"
  <-! extract "#prefix.fonts.zip" "./#prefix.fonts/"

  fonts = ls "./#prefix.fonts/*"
  
  # release filename (without CRC) is defined here
  # vx is for v2, v3, etc - it's not set by default
  # you will need to edit various strings to change
  # the filename scheme properly, places are marked
  ## FILENAME SCHEME ##
  cmd = """
  mkvmerge -o "[#group] #show - #num#vx (720p).mkv"
  --disable-track-statistics-tags
  "#prefix.premux.720p.mkv"
  
  """

  for l, n of langs
    cmd += """
    --language "0:#l"
    --track-name "0:#n"
    "#prefix.release.#l.ass"
  
    """

  for f in fonts
    file = (f.match filename)?1
    fext = (file.match ext)?1
    mime = 'application/x-truetype-font'

    cmd += """
    --attachment-mime-type "#mime"
    --attachment-name "#file"
    --attach-file "#f"
  
    """

  # MKV title is set here
  cmd += """
  --title "#title - #num - #{episodes[num]}"
  """
  # you can also add --chapters to the above
  # if you mux chapters only at this point
    
  console.log "Muxing episode #num#vx..."

  <-! run cmd

  next!

## `crc`
# CRC32 hash the episode mux and append it to the filename.
target.crc = (num, next) !->
  ## FILENAME SCHEME ##
  file = "[#group] #show - #num#vx (720p)"

  checksum = void
  parts = <[ B KB MB GB ]>
  size = 0
  console.log "Hashing episode #num#vx..."
  source = fs.create-read-stream "#file.mkv"
  source.on \data (chunk) !->
    if chunk
      size += chunk.length
      checksum := crc chunk, checksum
  <-! source.on \end
  text = checksum.to-string \hex .to-upper-case!
  ext = 0
  while size > 1024
    size := size / 1024
    ext++

  log "Filesize: #{size.to-fixed 2} #{parts[ext]}, CRC32: #text"
  ## FILENAME SCHEME (the latter is how CRC32 is appended) ##
  mv "./#file.mkv" "./#file [#text].mkv"
  next!

## `patch`
# Creates an .xdelta patch from premux to release.
target.patch = (num, next) !->

  premux = "#name.#num.premux.720p.mkv"
  ## FILENAME SCHEME ##
  file = (ls "[#group] #show - #num#vx (720p)*.mkv")?0
  console.log "Premux patching episode #num#vx..."
  <-! run """xdelta3 -e -s #premux "#file" #name.#num#vx.mux.xdelta"""

  next!

## `torrent`
# Creates a torrent file for the release mux.
target.torrent = (num, next) !->

  ## FILENAME SCHEME ##
  input = (ls "[#group] #show - #num#vx*.mkv")?0
  torrent = input + ".torrent"
  tracker = "http://open.nyaatorrents.info:6544/announce"
  opts = {
    comment: irc
    # trackers used in the torrent are defined here
    # edit how you wish, but the first one should
    # match the one defined above
    announce-list: [
      [new Buffer "http://open.nyaatorrents.info:6544/announce"]
      [new Buffer "udp://open.demonii.com:1337/announce"]
      [new Buffer "udp://tracker.openbittorrent.com:80/announce"]
      [new Buffer "udp://tracker.publicbt.com:80/announce"]
    ]
  }

  console.log "Creating torrent for episode #num#vx..."
  err, tor <-! nt.make-write torrent, tracker, "#__dirname", [input], opts
  if err then throw err

  next!

## `rel`
# Runs the release creation process.
target.rel = (num, next) !->

  <-! target.mux num
  <-! target.crc num
  <-! target.patch num
  <-! target.torrent num
  next!

## `v2`
# Same as above, except run with version set to v2.
target.v2 = (num, next) !->

  vx := "v2"
  <-! target.rel num
  next!

## `v3`
# Hopefully you won't have a need for this.
target.v3 = (num, next) !->

  vx := "v3"
  <-! target.rel num
  next!