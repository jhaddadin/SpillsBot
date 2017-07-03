# SpillsBot
Ruby script to monitor environmental hazards reported to the Massachusetts Department of Environmental Protection and tweet information about new releases. The script uses Wattir to navigate through the DEP website and download PDFs of all new reportable releases. It converts each PDF to a text file using the PDFtotext utility, then uses Nokogiri to parse the text for the time, location and description of each release. Finally, it uses ImageMagik to create an animated GIF showing the location of each spill using a series of Google Maps images.

# Example
<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">7/11 10:51AM<br>Alighieri Montessori School<br>37 Gove St, East Boston<br>LEAD<a href="https://t.co/4y4A3qEjbI">https://t.co/4y4A3qEjbI</a> <a href="https://t.co/bbB4WfJgb8">pic.twitter.com/bbB4WfJgb8</a></p>&mdash; SpillsBot (@MassSpillsBot) <a href="https://twitter.com/MassSpillsBot/status/752929955328188416">July 12, 2016</a></blockquote>
<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

Note: This Twitter account is no longer active. RIP @SpillsBot.
