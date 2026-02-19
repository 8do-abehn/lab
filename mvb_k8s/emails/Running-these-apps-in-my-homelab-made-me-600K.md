# Running these apps in my homelab made me $600K

**From:** Mischa van den Burg <news@kubecraft.dev>  
**Date:** Mon, 01 Dec 2025 18:40:21 +0000

---

Hey Adam,

​

One of the questions I get often is: so I built my home lab. What
do I do with it?

And it’s one of my favorite questions to answer.

Every week I host several live Q&A calls in KubeCraft (
https://click.convertkit-mail2.com/n4uzz385kgbvhxew6qnt6h68xz5ggflhg7pqx/6qheh8hlolm3p9co/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svYTI5ZTc2
).

And this question comes up regularly.

During these mentorship sessions, I teach my students a process
that you won't find anywhere else.

So instead of just giving you a list of apps to run, I’ll share
my whole thought process so you can decide for yourself.

I think that will serve you better than a list of apps.

​

But before we jump in, I should let you know that I'm only
accepting 10 new students in December.

If you want to get direct mentorship from me, CLICK HERE (
https://click.convertkit-mail2.com/n4uzz385kgbvhxew6qnt6h68xz5ggflhg7pqx/6qheh8hlolm3p9co/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svYTI5ZTc2
) to claim your spot.

I'll help you land a remote, 6-figure DevOps job so you can live
the life of your dreams.

​

--------------------------
What is a home lab anyway?
--------------------------

First of all, let’s think about what a home lab is.

One big misconception people have is that home labs need to be
big server racks with thousands of dollars of equipment.

They think you need to run 5 node Kubernetes clusters before you
can even call it a home lab.

This is completely false.

My home lab started with a ThinkPad T430. An old laptop that was
gathering dust in a closet.

I installed Linux on there, and ran Linkding in a Docker
container.

I was so proud. I had my own little application that I could run.

I was self-hosting. And it all started from there.

​

-------------------------------
Solve Problems You Already Have
-------------------------------

When I get the question, “what should I run?”, my first reaction
is always to solve problems you already have in your life.

The reason why I ended up self-hosting Linkding was because I was
switching browsers so often.

I would sometimes have three different browsers running.

One on my phone, one on my laptop, and one on my main
workstation.

I needed a place to store my bookmarks that was independent of
the browser.

And after using Raindrop for a while, I somehow discovered
Linkding.

I’ve been using it for over 3 years now.

So here’s what I encourage you to do:

Try to think of something that you find yourself doing
repeatedly.

A chore that keeps coming back and that you don’t like doing.

Then find a way to automate that.

For example, you can automate the dimming of lights using Home
Assistant.

One friend of mine scrapes the current prices of power, and
calculates whether he should run his laundry machine in the
morning or in the evening.

Everybody has different problems. So I can't tell you which one
to pick.

But here's one of the main problems I fixed for myself:

------------
Storing Data
------------

The second main use-case I have for my own home lab is to store
data.

I’m a fond user of all sorts of tracking devices.

I use both WHOOP and and Oura ring to track my sleep and other
health metrics.

I track all the calories I eat in in Macrofactor.

(Though I am not perfect and I do have weeks where I slack on
this)

I also weigh myself every morning.

All of these devices are generating data that’s being stored by
other companies.

I can access the data from their portals and apps, but I don’t
really own that data.

This was bothering me to no end, so I decided to create my own
services that extract the data from these applications and store
them in my own databases.

I had a problem that I wanted to solve.

But one other thing that plays a role in my home lab decision
making process is whether something has relevance for my
development as an engineer.

At the time I was working for a company that used the EDB
operator (
https://click.convertkit-mail2.com/n4uzz385kgbvhxew6qnt6h68xz5ggflhg7pqx/kkhmh6hnmnko8ocl/aHR0cHM6Ly93d3cuZW50ZXJwcmlzZWRiLmNvbQ==
) to run Postgres databases on Kubernetes.

I wanted to learn more about Kubernetes database operations.

I decided to combine my desire to store my tracker data with my
interest in running databases and interacting with them from
code.

After a weekend of tinkering I had a scraper that would grab all
of my Oura data and store it in a postgres database.

And the best part was that I could visualize it with Grafana
dashboards!

​

​
As a side note, I actually used to do this from my self-hosted
n8n instance, but Oura recently made a change.

They won’t allow you to authenticate with PAT tokens anymore, so
I had to create a new applications that authorizes with an Oauth2
flow.

If you’re interested you can view the source code here:

​https://github.com/mischavandenburg/oura-scraper (
https://click.convertkit-mail2.com/n4uzz385kgbvhxew6qnt6h68xz5ggflhg7pqx/25h2hoh3d3kq75i3/aHR0cHM6Ly9naXRodWIuY29tL21pc2NoYXZhbmRlbmJ1cmcvb3VyYS1zY3JhcGVy
)​

​

--------
The Goal
--------

The main goal of the home lab is to have a place where you can
experiment and develop yourself.

But to what end do you do this? Is it only for fun?

I already alluded to it earlier in this newsletter, but the home
lab is much more than a place to learn tech.

It’s your personal portfolio to land remote 6 figure DevOps jobs.

Because that’s why you’re here right?

You want to work where you want, with the people you want, on the
people you want.

The home lab is what hundreds of my students have done to land
these kinds of jobs.

Some times within a couple of weeks!

​

​
​

​

When you join KubeCraft, you get a complete system that will
teach you to become a DevOps engineer from scratch.

One of these systems is called Homelab OS.

This is an extremely deep course that will take you from zero
Kubernetes knowledge to building a public homelab that acts as an
irresistible portfolio project.

Home labs are fun, and a great hobby to practice.

But if you want a remote 6-figure DevOps job, you have to stop
playing around and start taking action.

​CLICK HERE (
https://click.convertkit-mail2.com/n4uzz385kgbvhxew6qnt6h68xz5ggflhg7pqx/6qheh8hlolm3p9co/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svYTI5ZTc2
) to get access to Homelab OS and to start making $171K+ a year.

​

​

Take the teachings from this newsletter and use them to find home
lab use cases that make your life better.

It is the most satisfying hobby I have ever started, and I’m not
going to stop any time soon.

Keep striving for that remote job and complete autonomy,

Mischa

​

P.S. We are only accepting 10 students for the December cohort.
CLICK HERE (
https://click.convertkit-mail2.com/n4uzz385kgbvhxew6qnt6h68xz5ggflhg7pqx/6qheh8hlolm3p9co/aHR0cHM6Ly9rdWJlY3JhZnQuY2xpY2svYTI5ZTc2
) to claim your spot before they run out.

​

​

​
113 Cherry St #92768, Seattle, WA 98104-2205 | Unsubscribe (
https://unsubscribe.convertkit-mail2.com/n4uzz385kgbvhxew6qnt6h68xz5ggflhg7pqx
) | Update your profile (
https://preferences.convertkit-mail2.com/n4uzz385kgbvhxew6qnt6h68xz5ggflhg7pqx
)
