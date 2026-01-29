"""
Learning K8s with MVB - KubeCraft Course Email Parser

This module provides classes to parse and work with the KubeCraft
7-Day Kubernetes Quickstart Course emails.

Author: Adam (with Claude's help as a learning exercise)
Purpose: Parse course emails into structured data and generate GitHub tasks

LEARNING NOTES:
- A 'class' in Python is like a blueprint for creating objects
- Classes group related data (attributes) and functions (methods) together
- This is called Object-Oriented Programming (OOP)
"""

import os
import json
import re
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Optional, Dict
from email import policy
from email.parser import BytesParser


# The @dataclass decorator automatically creates __init__, __repr__, etc.
# It's a cleaner way to define classes that mainly hold data
@dataclass
class KubectlCommand:
    """
    Represents a kubectl command from the course.

    Attributes:
        command: The full kubectl command string
        description: What this command does
        category: The type of operation (get, create, delete, etc.)
    """
    command: str
    description: str = ""
    category: str = ""

    def __post_init__(self):
        """Called after the object is created. We use it to auto-categorize."""
        if not self.category:
            # Extract the kubectl subcommand (get, create, delete, etc.)
            parts = self.command.split()
            if len(parts) >= 2 and parts[0] == "kubectl":
                self.category = parts[1]


@dataclass
class LearningTask:
    """
    Represents a hands-on task to complete for the course.

    These will become GitHub issues for tracking progress.
    """
    title: str
    description: str
    day: int
    commands: List[str] = field(default_factory=list)
    concepts: List[str] = field(default_factory=list)
    completed: bool = False

    def to_github_issue(self) -> Dict:
        """
        Convert this task to a format suitable for GitHub issues.

        Returns:
            A dictionary with 'title', 'body', and 'labels' keys
        """
        # Build the issue body with markdown formatting
        body_parts = [
            f"## Day {self.day} Task",
            "",
            self.description,
            ""
        ]

        if self.commands:
            body_parts.append("### Commands to Practice")
            body_parts.append("```bash")
            body_parts.extend(self.commands)
            body_parts.append("```")
            body_parts.append("")

        if self.concepts:
            body_parts.append("### Key Concepts")
            for concept in self.concepts:
                body_parts.append(f"- {concept}")
            body_parts.append("")

        body_parts.append("---")
        body_parts.append("*Generated from KubeCraft 7-Day Kubernetes Quickstart Course*")

        return {
            "title": f"[Day {self.day}] {self.title}",
            "body": "\n".join(body_parts),
            "labels": ["kubernetes", "learning", f"day-{self.day}"]
        }


@dataclass
class Lesson:
    """
    Represents a single day's lesson from the course.

    This class holds all the extracted data from one email.
    """
    day: int
    subject: str
    date_received: str
    topics_covered: List[str] = field(default_factory=list)
    key_concepts: List[str] = field(default_factory=list)
    kubectl_commands: List[KubectlCommand] = field(default_factory=list)
    what_you_learned: List[str] = field(default_factory=list)
    raw_content: str = ""

    def get_tasks(self) -> List[LearningTask]:
        """
        Generate hands-on learning tasks from this lesson.

        Returns:
            A list of LearningTask objects for this day
        """
        tasks = []

        # Task 1: Read and understand the concepts
        tasks.append(LearningTask(
            title=f"Read and understand: {self.subject}",
            description=f"Read through the Day {self.day} email and understand the key concepts before practicing.",
            day=self.day,
            concepts=self.key_concepts[:5] if self.key_concepts else self.topics_covered[:5]
        ))

        # Task 2: Practice the commands (if any)
        if self.kubectl_commands:
            cmd_strings = [cmd.command for cmd in self.kubectl_commands[:8]]
            tasks.append(LearningTask(
                title=f"Practice kubectl commands from Day {self.day}",
                description=f"Open a terminal with access to your Kubernetes cluster and practice these commands.",
                day=self.day,
                commands=cmd_strings
            ))

        # Task 3: Self-assessment based on what you learned
        if self.what_you_learned:
            tasks.append(LearningTask(
                title=f"Self-assessment: Day {self.day} concepts",
                description="Review what you learned and make sure you can explain each concept in your own words.",
                day=self.day,
                concepts=self.what_you_learned
            ))

        return tasks


class K8sCourse:
    """
    Main class representing the entire KubeCraft Kubernetes course.

    This class can:
    - Load lessons from a JSON summary file
    - Parse raw email files
    - Generate GitHub issues for tracking progress
    - Provide course statistics and progress tracking

    USAGE:
        # Create an instance
        course = K8sCourse()

        # Load from JSON summary
        course.load_from_json("email_summary.json")

        # Get all tasks
        all_tasks = course.get_all_tasks()

        # Export tasks for GitHub
        github_issues = course.export_github_issues()
    """

    def __init__(self):
        """Initialize an empty course."""
        self.name: str = "7-Day Kubernetes Quickstart Course"
        self.provider: str = "KubeCraft"
        self.instructor: str = "Mischa van den Burg"
        self.lessons: List[Lesson] = []
        self.email_dir: Optional[str] = None

    def load_from_json(self, json_path: str) -> None:
        """
        Load course data from a JSON summary file.

        Args:
            json_path: Path to the JSON file created by the email parser
        """
        with open(json_path, 'r') as f:
            data = json.load(f)

        # Update course info from JSON
        if 'course_info' in data:
            self.name = data['course_info'].get('name', self.name)
            self.provider = data['course_info'].get('provider', self.provider)
            self.instructor = data['course_info'].get('instructor', self.instructor)

        # Parse lesson emails into Lesson objects
        for lesson_data in data.get('lesson_emails', []):
            # Convert kubectl command strings to KubectlCommand objects
            commands = [
                KubectlCommand(command=cmd)
                for cmd in lesson_data.get('kubectl_commands', [])
            ]

            lesson = Lesson(
                day=lesson_data.get('day', 0),
                subject=lesson_data.get('subject', ''),
                date_received=lesson_data.get('date_received', ''),
                topics_covered=lesson_data.get('topics_covered', []),
                key_concepts=lesson_data.get('key_concepts', []),
                kubectl_commands=commands,
                what_you_learned=lesson_data.get('what_you_learned_today', [])
            )
            self.lessons.append(lesson)

        # Sort lessons by day number
        self.lessons.sort(key=lambda x: x.day)

    def get_lesson(self, day: int) -> Optional[Lesson]:
        """
        Get a specific day's lesson.

        Args:
            day: The day number (1-6)

        Returns:
            The Lesson object for that day, or None if not found
        """
        for lesson in self.lessons:
            if lesson.day == day:
                return lesson
        return None

    def get_all_tasks(self) -> List[LearningTask]:
        """
        Get all learning tasks from all lessons.

        Returns:
            A flat list of all LearningTask objects
        """
        all_tasks = []
        for lesson in self.lessons:
            all_tasks.extend(lesson.get_tasks())
        return all_tasks

    def export_github_issues(self) -> List[Dict]:
        """
        Export all tasks as GitHub issue format.

        Returns:
            A list of dictionaries, each representing a GitHub issue
        """
        tasks = self.get_all_tasks()
        return [task.to_github_issue() for task in tasks]

    def export_github_issues_json(self, output_path: str) -> None:
        """
        Export GitHub issues to a JSON file.

        Args:
            output_path: Where to save the JSON file
        """
        issues = self.export_github_issues()
        with open(output_path, 'w') as f:
            json.dump(issues, f, indent=2)
        print(f"Exported {len(issues)} GitHub issues to {output_path}")

    def get_stats(self) -> Dict:
        """
        Get statistics about the course.

        Returns:
            A dictionary with course statistics
        """
        total_commands = sum(len(l.kubectl_commands) for l in self.lessons)
        total_concepts = sum(len(l.key_concepts) for l in self.lessons)
        total_tasks = len(self.get_all_tasks())

        return {
            "course_name": self.name,
            "total_lessons": len(self.lessons),
            "total_kubectl_commands": total_commands,
            "total_concepts": total_concepts,
            "total_tasks": total_tasks,
            "lessons_by_day": {
                l.day: l.subject for l in self.lessons
            }
        }

    def print_summary(self) -> None:
        """Print a human-readable summary of the course."""
        stats = self.get_stats()

        print(f"\n{'='*60}")
        print(f"  {self.name}")
        print(f"  by {self.instructor} ({self.provider})")
        print(f"{'='*60}\n")

        print(f"Total Lessons: {stats['total_lessons']}")
        print(f"Total kubectl Commands: {stats['total_kubectl_commands']}")
        print(f"Total Key Concepts: {stats['total_concepts']}")
        print(f"Total Learning Tasks: {stats['total_tasks']}")

        print(f"\n{'Lessons:':-^40}")
        for day, subject in stats['lessons_by_day'].items():
            print(f"  Day {day}: {subject}")
        print()


def main():
    """
    Main function - demonstrates how to use the K8sCourse class.

    This runs when you execute the script directly:
        python k8s_course.py
    """
    # Find the JSON summary file
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Try a few possible locations for the JSON file
    possible_paths = [
        os.path.join(script_dir, "email_summary.json"),
        "/sessions/clever-kind-feynman/email_summary.json",
    ]

    json_path = None
    for path in possible_paths:
        if os.path.exists(path):
            json_path = path
            break

    if not json_path:
        print("Error: Could not find email_summary.json")
        print("Please run the email parser first or specify the correct path.")
        return

    # Create the course and load data
    course = K8sCourse()
    course.load_from_json(json_path)

    # Print summary
    course.print_summary()

    # Export GitHub issues
    issues_path = os.path.join(script_dir, "github_issues.json")
    course.export_github_issues_json(issues_path)

    # Show a sample task
    tasks = course.get_all_tasks()
    if tasks:
        print("\nSample Task (first one):")
        print("-" * 40)
        sample = tasks[0].to_github_issue()
        print(f"Title: {sample['title']}")
        print(f"Labels: {sample['labels']}")
        print(f"\nBody:\n{sample['body'][:500]}...")


if __name__ == "__main__":
    main()
