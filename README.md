# SpillsBot
Ruby script to monitor environmental hazards reported to the Massachusetts Department of Environmental Protection and tweet information about new releases.

The script uses Watir to navigate through the DEP website and download PDFs of all new reportable releases. It converts each PDF to a text file using the pdftotext utility, then uses Nokogiri to parse the text. It records the time, location and description of each release.

Finally, it uses ImageMagik to create an animated GIF showing the location of each spill using a series of Google Maps images. Tweets are posted automatically by the [@MassSpillsBot](https://twitter.com/MassSpillsBot) Twitter account.

### Example from [@MassSpillsBot](https://twitter.com/MassSpillsBot)

https://twitter.com/MassSpillsBot/status/752929955328188416

Note: This Twitter account is no longer active. RIP @MassSpillsBot.
