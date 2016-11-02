Received: from rune.listbox.com (rune.listbox.com [208.210.124.79])
	by dream.listbox.com (Postfix) with ESMTP id 20FF3107FB2
	for <rubric@v2.listbox.com.email.sent.archive.listbox.com>; Sat, 28 Jan 2006 13:43:25 -0500 (EST)
Received: by rune.listbox.com (Postfix, from userid 440)
	id 258A5280B9; Sat, 28 Jan 2006 13:43:24 -0500 (EST)
Received: (qmail 13334 invoked by uid 1014); 28 Jan 2006 18:43:19 -0000
Date: Sat, 28 Jan 2006 13:43:18 -0500
From: Ricardo SIGNES <rjbs-rubric@lists.manxome.org>
To: rubric@listbox.com
Subject: recent rubric updates
Message-ID: <20060128184318.GB27474@manxome.org>
Mime-Version: 1.0
Content-Type: multipart/signed; micalg=pgp-sha1;
	protocol="application/pgp-signature"; boundary="hRt258QUzs6ToQn5"
Content-Disposition: inline
X-Message-Flag: Warning: This message was sent by a user who doesn't like Outlook.
X-Planet: Planet of the Apes
User-Agent: Mutt/1.5.10i
X-Listbox-Original-Sender: Ricardo SIGNES <rjbs-rubric@lists.manxome.org>
X-Listbox-Spam-Status: No, score=0 required=8 tests=
X-Listbox-Action: yay
X-Listbox-Flag: from_active
X-Listbox-Reason: rjbs-rubric@lists.manxome.org is subscribed
X-Listbox-Archive-UUID: F51A31A2-902D-11DA-86CE-A3C6D1A4D48D
Lines: 43

--hRt258QUzs6ToQn5
Content-Type: text/plain; charset=us-ascii
Content-Disposition: inline
Content-Transfer-Encoding: quoted-printable


So, I've been pretty lazy (alternately, busy with other things), but
I've made a number of commits to Rubric lately.  By the way, you can
check Rubric out here:

  http://svn.codesimply.com/projects/rubric/

The largest change has been in creating Rubric::CLI, which will be the
foundation for a new "rubric" command that will do things like "create
users" and "approve users" and "update db schema" and "install new
Rubric" and so on.

Someone is working on the first non-trivial Rubric::Entry::Formatter
plugin, and I am excited by the prospect.  I need to write some of those
myself!

My need for Rubric-for-images is getting critical, so hopefully I'll be
talking about how I'll do that soon, too.

Contributions, complaints, or ideas for how to make the CLI most useful
are welcome.

--=20
rjbs

--hRt258QUzs6ToQn5
Content-Type: application/pgp-signature
Content-Disposition: inline

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.2 (GNU/Linux)

iD8DBQFD27tG5IEwYcR13KMRAjjaAJ9ue0MhsxYo8D7LmM8jw0nH2eSecgCfUi2t
CxFAfjKVAv54dGtwRXryiWQ=
=21d5
-----END PGP SIGNATURE-----

--hRt258QUzs6ToQn5--
