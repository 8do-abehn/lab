---
title: "Building an AI-Powered Job Search System with Claude Projects"
date: 2026-02-26
draft: false
tags: ["ai", "claude", "productivity", "career"]
---

## The Problem

Job hunting is repetitive. Every application means re-reading your own resume, figuring out how to position your experience for this specific role, writing yet another cover letter, and hoping a recruiter connects the dots. Multiply that by dozens of applications and it gets exhausting fast.

I wanted a system where I could drop in a job posting and get back an honest fit assessment, a tailored resume, and a cover letter without re-explaining my entire background every time.

## The Philosophy

Your goal is to get interviews. Not every one will be for your dream job, and that's the point. Every interview makes you sharper. Your answers get tighter. Your ability to read a room improves. With a system that captures debriefs and tracks your progress, all of that experience compounds. When the role you really want comes along, you're not walking in cold. You're walking in with reps.

## The Approach

I set up a Claude Project as a persistent job search assistant. The key insight is that Claude Projects retain context across conversations, so you seed it once with your career materials and then each new chat starts with full knowledge of who you are.

Four documents seed the project:

1. **Career history** - the detailed, honest, unpolished version of your work history. Not your resume. The real story, including what was hard and why you left.
2. **Resume** - your current baseline, whatever you have.
3. **Cover letter** - an example showing your preferred voice and style.
4. **Instructions** - rules for how AI should show up: fit assessment criteria, resume writing standards, interview prep guidance, and workflow conventions.

## How It Works in Practice

For each opportunity, I start a new chat and drop in the job posting. The system:

1. **Evaluates fit** before I invest time tailoring anything. Green/yellow/red assessment based on skills overlap, scope match, and honest self-evaluation.
2. **Tailors the resume** with impact-focused bullets that connect my background to the specific role. Every bullet leads with scale or metrics, not responsibilities.
3. **Generates a cover letter** that references something real about the company, not generic enthusiasm.
4. **Suggests filenames** following my naming convention so I can save directly to my organized folder structure.

When a role reaches the interview stage, the same context powers interview prep. It knows the job description, my tailored resume, and my real career history (including the messy parts), so it can help me prepare for tough questions honestly.

## The Career History Is the Secret Weapon

Most people seed AI with their polished resume and get polished-but-generic output back. The career history document is different. It includes:

- What you actually did day to day, not the sanitized version
- Why you really left each role
- What was hard or went wrong
- What you're proud of even if you can't quantify it
- Your working style, preferences, and deal-breakers

This context is what lets AI tell you "this role is a bad fit because the last time you were in that environment, you were miserable" instead of just pattern-matching keywords.

Write it in whatever format works for you. Stream of consciousness is fine. Share as much or as little as you're comfortable with. It only lives in your AI project.

## Review Everything, Trust Nothing Blindly

One thing I learned quickly: always read every resume and cover letter before sending it. Even with explicit instructions not to fabricate, AI will sometimes hallucinate experience, exaggerate scope, or claim you worked in an industry you've never touched. It's not malicious, it's just pattern matching gone wrong.

The fix is simple but ongoing. When you catch something, tell AI to remember it: "Add a memory: I did not complete the SOC2 audit" or "Add a memory: stop saying I worked in healthcare." The more corrections you make, the more accurate the output gets. Think of the first few rounds as a calibration period where you're training it on what's actually true about your career.

The instructions include an honesty policy, but you are still the final quality check. Do not skip this step.

## Tracking and Reporting

Each chat gets renamed to `Company_RoleName` and each opportunity gets a folder following `Company_Role_Stage` naming. When a role closes, I do a quick debrief in the chat: how far I got, what feedback I received, what I'd do differently.

Over time this becomes a searchable dataset. I can ask for a report on stage distribution (where am I getting screened out?), which industries are responding, which skills keep coming up, and whether my approach needs adjusting.

## The Urgency Factor

One thing I built into the instructions: AI should factor in your current runway. The advice for someone still employed and casually exploring is very different from someone with a month of severance left. Keeping this updated changes the coaching from "be selective" to "cast a wider net."

## Unemployment Work Search Reports

If you're collecting unemployment, most states require documented proof of job search activity. Instead of maintaining a separate spreadsheet, just ask AI for a work search report. It pulls from your conversations and generates a table with date applied, company, position, website, and result. Copy-paste ready for your state's certification form.

This was one of those features that came out of real need. When you're already stressed about finding work, the last thing you want is another tracking chore.

## Watching Career Pages with Change Detection

Don't just refresh your dream company's careers page every week. Use a change detection tool like [changedetection.io](https://changedetection.io) to monitor it for you. When a new role gets posted, you get a notification. Drop the posting into your project chat and you're already running through fit assessment while everyone else is still finding it on LinkedIn three weeks later.

I set up a separate Claude Project where AI acts as a changedetection.io expert to help me tune the CSS selectors and filters for each company's careers page. Different sites structure their job listings differently, and having AI help dial in the detection saves a lot of trial and error.

## Other Tools That Helped

A few other things I used alongside the Claude Project:

- **[job-scout](https://github.com/8do-abehn/job-scout)** - A self-hosted job search tool that scrapes multiple job boards, tracks applications via GitHub Issues with a project board, and includes an MCP server for searching directly from Claude. Fair warning: I recently had AI anonymize the repo for public release and haven't had time to verify the setup instructions from scratch yet. If something's off, open an issue.
- **Claude Code Chrome extension** - Useful for pulling job descriptions off company career pages and gathering company info during interview prep. Having AI read the page you're looking at and summarize it in context saves a lot of copy-pasting.
- **changedetection.io** - Monitors career pages at companies you want to work for and notifies you when new roles appear.

I plan to write more about each of these in future posts.

## What I Published

I genericized the whole system and published it as a starter kit:

**[job-hunt-project-claude on GitHub](https://github.com/8do-abehn/job-hunt-project-claude)**

It includes:
- A README walking through the full setup
- Project instructions ready to paste into a Claude Project
- Starter templates for resume, cover letter, and career history (use your own if you have them)

Fork it, fill in your own materials, and you have a working system. But actually read the instructions before you use them. Remove stuff. Add stuff. See what it does. I built all of this iteratively as I went through my own search, so I could see the impact of each change in real time. If you just copy-paste it blindly, you're trusting a stranger's workflow without understanding why any of it is there. Make it yours. Good luck.

## One More Thing: Don't Sound Like AI

AI has recognizable writing patterns, and recruiters are increasingly aware of them. If your resume reads like a chatbot wrote it, that undermines everything this system is trying to do.

The project instructions include rules to avoid common AI tells: inflated language, overused transitions, uniform sentence structure, and that polished-but-generic tone. But you still need to read every output and make sure it sounds like you. For a detailed reference on what to watch for, see [Wikipedia: Signs of AI Writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing). It's worth reading once and keeping in mind as you review your materials.
