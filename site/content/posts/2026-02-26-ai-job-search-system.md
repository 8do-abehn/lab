---
title: "Building an AI-Powered Job Search System with Claude Projects"
date: 2026-02-26
draft: false
tags: ["ai", "claude", "productivity", "career"]
---

## The Problem

Job hunting is repetitive. Every application means re-reading your own resume, figuring out how to position your experience for this specific role, writing yet another cover letter, and hoping a recruiter connects the dots. Multiply that by dozens of applications and it gets exhausting fast.

I wanted a system where I could drop in a job posting and get back an honest fit assessment, a tailored resume, and a cover letter without re-explaining my entire background every time.

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

## Tracking and Reporting

Each chat gets renamed to `Company_RoleName` and each opportunity gets a folder following `Company_Role_Stage` naming. When a role closes, I do a quick debrief in the chat: how far I got, what feedback I received, what I'd do differently.

Over time this becomes a searchable dataset. I can ask for a report on stage distribution (where am I getting screened out?), which industries are responding, which skills keep coming up, and whether my approach needs adjusting.

## The Urgency Factor

One thing I built into the instructions: AI should factor in your current runway. The advice for someone still employed and casually exploring is very different from someone with a month of severance left. Keeping this updated changes the coaching from "be selective" to "cast a wider net."

## Unemployment Work Search Reports

If you're collecting unemployment, most states require documented proof of job search activity. Instead of maintaining a separate spreadsheet, just ask AI for a work search report. It pulls from your conversations and generates a table with date applied, company, position, website, and result. Copy-paste ready for your state's certification form.

This was one of those features that came out of real need. When you're already stressed about finding work, the last thing you want is another tracking chore.

## What I Published

I genericized the whole system and published it as a starter kit:

**[job-hunt-project-claude on GitHub](https://github.com/8do-abehn/job-hunt-project-claude)**

It includes:
- A README walking through the full setup
- Project instructions ready to paste into a Claude Project
- Starter templates for resume, cover letter, and career history (use your own if you have them)

Fork it, fill in your own materials, and you have a working system. The instructions evolve as you use it and learn what works for your search.
