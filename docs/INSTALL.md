# Installing AllyKeyboard

There are two ways. **Homebrew is the one to use** — it installs the keyboard
and nothing stands in your way. The `.dmg` works too, but macOS will refuse to
open the app once, and you will have to tell it to allow it.

The short version is in the [README](../README.md). This page is for when
something asks a question you did not expect.

---

## Why there are two ways, and why one of them is awkward

AllyKeyboard is signed with a certificate I made myself, not one issued by
Apple. Apple's is part of a paid developer membership, and this is a free
application given away to a handful of people, so it has not been bought.

macOS treats anything downloaded from the internet that Apple has not vouched
for as suspect: it attaches an invisible "quarantine" mark to the file and
refuses to launch it. The mark is attached by whatever downloads the file.

**Homebrew removes that mark for you as part of installing.** A web browser does
not, and nothing inside the downloaded file can remove it either. That is the
whole of the difference between the two methods.

It matters more here than for most software. The documented way out of the
refusal is a command typed into Terminal — and this is the application people
install because typing is what they cannot do. If you are setting this up for
someone else, use Homebrew and spare them the whole question.

---

## Method 1 — Homebrew (recommended)

### What Homebrew is

A package manager for macOS: a program that installs other programs. One command
installs an application, another updates it, a third removes it cleanly. It is
free, widely used, and installs into its own folder without touching the system.

### If you do not have it yet

Open **Terminal** (⌘Space, type `Terminal`, Enter) and paste this single line,
which comes from [brew.sh](https://brew.sh):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It asks for your account password — the same one you log in with — and may
install Apple's Command Line Tools first, which takes a few minutes. When it
finishes it prints two or three commands of its own; run them, or Homebrew will
not be found afterwards.

### Install AllyKeyboard

```bash
brew tap umkasanki/tap
brew trust umkasanki/tap
brew install --cask allykeyboard
```

The first line adds my collection of applications. The second says you trust it:
Homebrew asks this once for any collection that is not its own. Adding a *new*
application from the same collection later asks again — that is normal, not a
sign that something went wrong.

The third installs AllyKeyboard into your Applications folder and clears the
quarantine mark on the way, so it opens the first time without argument.

Then give it permission to type: **[Granting Accessibility](#granting-accessibility)**.

### Updating and removing

```bash
brew upgrade --cask allykeyboard      # update to the newest release
brew uninstall --cask allykeyboard    # remove the application
brew uninstall --zap --cask allykeyboard   # remove it and its settings
```

---

## Method 2 — the `.dmg` file

### What a `.dmg` is

A disk image: a single file that behaves like a disc. You double-click it, a
window opens with the application inside, and you drag that application into
your Applications folder. It is the ordinary way macOS software is handed out.

### Why this is the second choice here

Because of the quarantine mark described above: a browser attaches it, and macOS
will stop the first launch. You can get past it — the steps below are not hard —
but it is several extra actions, and one of them has to be done in System
Settings.

### Steps

**1. Download.** Open the [latest release](https://github.com/umkasanki/ally-keyboard/releases/latest)
and download `AllyKeyboard-<version>.dmg`. (There is also a `.zip` of the same
application; either will do, and both carry the same quarantine mark.)

**2. Install.** Double-click the downloaded file. A window opens showing the
AllyKeyboard application beside a shortcut to your Applications folder. Drag the
application onto that folder and let go.

Then close the window and eject the disk image — it appears in the Finder
sidebar under *Locations* with an eject symbol next to it.

**3. Try to open it — and expect to be refused.** Open your Applications folder
and double-click AllyKeyboard.

A dialog appears saying that macOS **cannot verify that the application is free
of malware**, and suggesting that you move it to the Bin. It does not offer to
open it: on current macOS the buttons are only *Move to Bin* and *Done*
(in Russian, «Переместить в Корзину» and «Готово»).

**Press Done.** Do not move it to the Bin — that deletes the application, and
then there is nothing left to allow.

**4. Allow it.** Open **System Settings** (the gear icon in the Dock, or the
Apple menu → System Settings), choose **Privacy & Security** in the sidebar, and
scroll the right-hand pane almost to the bottom, past App Management and Full
Disk Access, to the section headed **Security**.

There you will find a line saying that *"AllyKeyboard" was blocked to protect
your Mac*, and beside it a button **Open Anyway** («Всё равно открыть»). The
line only stays for about an hour after the refusal; if it is not there,
double-click the application once more and come back.

Press **Open Anyway**. macOS asks for your password or Touch ID, then asks once
more whether you are sure, with a button **Open**. Confirm.

**5. Open the app again.** It starts normally, and keeps starting normally from
now on.

> **Do not bother with "right-click → Open".** Older guides — including an
> earlier version of this one — say that holding Control and choosing Open gets
> past the block. On current macOS it does not; the application is refused
> anyway.

### If you are comfortable with Terminal

One command does what steps 3–5 do, before you ever launch the app:

```bash
xattr -dr com.apple.quarantine /Applications/AllyKeyboard.app
```

### Updating and removing

To update, download the newer file and drag the new application over the old
one, replacing it. The permission you granted is kept: it is tied to the signing
certificate rather than to that particular copy of the file.

To remove, drag AllyKeyboard from Applications to the Trash. Its settings live
in `~/Library/Preferences/com.umkasanki.AllyKeyboard.plist` if you want those
gone too.

---

## Granting Accessibility

AllyKeyboard types into other applications, and macOS does not let one
application send keystrokes to another unless you say so explicitly.

1. Open **System Settings → Privacy & Security**, and in the right-hand pane
   choose **Accessibility**.
2. A list of applications appears, each with a switch. Find **AllyKeyboard** and
   turn its switch on. macOS asks for your password or Touch ID.
3. If AllyKeyboard is not in the list at all, press the **+** button underneath
   it, find AllyKeyboard in your Applications folder, choose **Open**, then turn
   on the switch that appears.
4. **Quit AllyKeyboard and start it again.** This step is easy to miss and
   nothing works without it: the application reads its permissions once, when it
   starts, so a permission granted to a running application has no effect until
   the next launch.

Without this the keyboard appears on screen and its keys light up when you dwell
on them, but no letters reach the application you are trying to type into.

---

## When something is still wrong

**"AllyKeyboard is damaged and can't be opened."** The same quarantine mark,
phrased differently by macOS. Step 4 above fixes it, or the Terminal command.

**The keyboard appears but nothing is typed.** Accessibility permission is
missing or was lost. Check the list above; if AllyKeyboard is in it and switched
on, switch it off and on again, then restart the application.

**It worked, then stopped after an update.** Check Accessibility first. If the
entry has disappeared from the list entirely, add it again with **+**.

---

## Typing at the login screen

AllyKeyboard runs as part of your session and cannot appear on the macOS **login
window**, so it cannot type your password there. macOS has its own keyboard that
can: **System Settings → Accessibility → Keyboard → Accessibility Keyboard**.
Turn it on, and it is available before anyone has logged in.
