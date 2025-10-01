# How to Write Bug Bounty Reports: A Beginner's Guide

## Article 1: Understanding Bug Bounty Reports

### What is a Bug Bounty Report?

A bug bounty report is your way of communicating a security vulnerability to a company. Think of it as telling someone "hey, I found a problem in your house's lock" - but in a professional, detailed way.

### Why Reports Matter

Good reports help triagers (the people who review your findings) understand the issue quickly. A clear report means:
- Faster response times
- Better rewards
- Building your reputation
- Helping the company fix the issue

### The Golden Rule

**Make the triager's job easy.** They review dozens or hundreds of reports daily. A clear, well-structured report stands out and gets processed faster.

---

## Article 2: The Basic Structure of a Report

Every good bug report has these essential parts:

### 1. Title (One Line)
Be specific and clear. The title should tell the triager exactly what the issue is.

**Good examples:**
- `Stored XSS in Profile Biography Field`
- `IDOR Allows Viewing Other Users' Private Messages`
- `SQL Injection in Search Parameter`

**Bad examples:**
- `XSS Found` (too vague)
- `Critical Bug!!!` (not descriptive)
- `I found something` (useless)

### 2. Summary (2-3 sentences)
Briefly explain what you found and why it matters.

**Example:**
```
The user profile biography field does not properly sanitize input, 
allowing an attacker to inject malicious JavaScript. When other users 
view the profile, the script executes, potentially stealing session cookies.
```

### 3. Severity
Use the program's severity scale (usually: Critical, High, Medium, Low, Informational)

Don't inflate severity - triagers know the difference and it damages your credibility.

---

## Article 3: Steps to Reproduce - The Most Important Part

This section is where beginners often fail. Your steps must be **crystal clear** and **perfectly reproducible**.

### The Format

Number each step clearly. Write like you're explaining to someone who has never seen the website before.

### Good Example:

```
Steps to Reproduce:
1. Navigate to https://example.com/login
2. Log in with credentials: test@example.com / Password123
3. Click on "Profile" in the top navigation menu
4. Click the "Edit Profile" button
5. In the "Biography" field, paste: <script>alert('XSS')</script>
6. Click "Save Changes"
7. Navigate to https://example.com/profile/testuser
8. Observe the alert box popup (XSS executed)
```

### Bad Example:

```
Steps to Reproduce:
1. Go to the profile page
2. Add XSS payload
3. It works
```

**Why it's bad:** Not specific enough. Which profile page? What exact payload? How do you know it works?

### Pro Tips:
- Include exact URLs
- Include exact payloads (copy-paste ready)
- Mention any special account requirements
- Note any browser-specific behavior
- Test your own steps before submitting

---

## Article 4: Proof of Concept (PoC)

### What is a PoC?

Proof of Concept shows that your vulnerability is real and exploitable. It's the evidence that backs up your claim.

### Types of PoC:

**Screenshots** (Most common)
- Show the vulnerability in action
- Highlight important parts with arrows or boxes
- Include the URL bar in screenshots
- Show the impact clearly

**Video/GIF** (Best for complex vulnerabilities)
- Use tools like: Loom, OBS, or ShareX
- Keep it short (under 2 minutes)
- No need for audio - let the video speak

**HTTP Requests** (For technical vulnerabilities)
```
POST /api/user/update HTTP/1.1
Host: example.com
Cookie: session=abc123
Content-Type: application/json

{"biography":"<script>alert(1)</script>"}
```

**Code Snippets** (For exploitation)
```python
import requests

payload = "<script>alert(document.cookie)</script>"
data = {"biography": payload}
response = requests.post("https://example.com/api/profile", json=data)
```

### What NOT to Include:
- Don't show actual user data (blur sensitive info)
- Don't include too many screenshots (5-6 maximum)
- Don't use offensive payloads in your PoC

---

## Article 5: Impact - Explain the Damage

Triagers need to understand: **"Why should we care about this vulnerability?"**

### Structure Your Impact Section:

**1. What can an attacker do?**
List the concrete actions an attacker could perform.

**2. Who is affected?**
All users? Only admins? Guest users?

**3. What data is at risk?**
Personal info? Financial data? Account access?

### Example:

```
Impact:
An attacker can exploit this vulnerability to:
- Steal session cookies of any user who visits the malicious profile
- Perform actions on behalf of the victim (post comments, change settings)
- Redirect users to phishing sites
- Access sensitive account information

Affected Users: All registered users (approximately 100,000+ users)

Data at Risk: Session tokens, personal information visible in the account
```

### Avoid These Mistakes:
- ❌ "This is critical because XSS is dangerous"
- ❌ "An attacker could hack the entire system" (too vague)
- ❌ Copying impact statements from other reports

### Do This Instead:
- ✅ Be specific about the actual impact
- ✅ Consider the business context
- ✅ Be realistic about what's exploitable

---

## Article 6: Avoiding Triager Stress - Be Professional

Triagers are humans with busy jobs. Here's how to make their life easier:

### DO These Things:

**1. Test thoroughly before submitting**
- Verify the bug exists
- Check if it's already reported (read disclosed reports)
- Make sure your steps actually work

**2. Submit only valid findings**
- Not every odd behavior is a vulnerability
- Research whether something is actually exploitable
- Understand the difference between a bug and a security issue

**3. Be patient**
- First response can take 2-14 days
- Don't send "any update?" messages daily
- Trust the process

**4. Communicate clearly**
- Use proper English (or the program's language)
- No slang or informal language
- Be polite and professional

**5. Accept feedback gracefully**
- If marked as "Not Applicable" - learn why
- If it's a duplicate - that's okay, it happens
- If severity is downgraded - don't argue excessively

### DON'T Do These Things:

**1. Don't spam**
- ❌ "Sir please check my report"
- ❌ "Any updates?????"
- ❌ Sending same message multiple times

**2. Don't be demanding**
- ❌ "This is critical, pay me $5000"
- ❌ "I need response in 24 hours"
- ❌ "You must fix this immediately"

**3. Don't threaten**
- ❌ "I will disclose publicly if you don't respond"
- ❌ "I will report you to authorities"
- ❌ Any form of blackmail

**4. Don't submit junk**
- ❌ Self-XSS without impact
- ❌ Issues that require physical access
- ❌ Things already in the "Known Issues" list
- ❌ Out-of-scope findings

**5. Don't argue about every decision**
- ❌ Long essays about why they're wrong
- ❌ Insulting the triager's knowledge
- ❌ Comparing to other programs' payouts

---

## Article 7: Common Beginner Mistakes

### Mistake #1: Submitting Self-XSS
**Problem:** XSS that only affects yourself is usually not valid.

**Example of invalid:**
```
I can inject <script>alert(1)</script> in my own profile 
and it shows alert to me only.
```

**Why it's not valid:** You're attacking yourself. It must affect OTHER users.

---

### Mistake #2: Missing Authorization Checks Without Impact
**Problem:** Finding you can access an API endpoint without testing if it exposes data.

**Invalid report:**
```
The endpoint /api/users doesn't check authentication
```

**Valid report:**
```
The endpoint /api/users doesn't check authentication, allowing 
anyone to retrieve email addresses of all users. 
[Include proof showing the actual data leak]
```

---

### Mistake #3: Information Disclosure Without Sensitivity
**Problem:** Reporting version numbers or non-sensitive info as vulnerabilities.

**Usually invalid:**
- Server version in headers
- Technology stack disclosure
- Non-sensitive error messages
- CSS/JS file names

**Valid only if:** You can show it leads to exploitation of a known CVE or reveals sensitive data.

---

### Mistake #4: Lack of Testing
**Problem:** Assuming something is vulnerable without testing.

**Bad approach:**
"The password reset might be vulnerable to race conditions"

**Good approach:**
"I tested the password reset with 50 concurrent requests and 
successfully reset the account twice. [Include logs/proof]"

---

### Mistake #5: Copy-Pasting Reports
**Problem:** Using templates without customizing for the specific vulnerability.

Triagers spot this immediately and it looks unprofessional.

---

## Article 8: Report Template for Beginners

Here's a simple template you can use:

```
Title: [Vulnerability Type] in [Location]

Summary:
[2-3 sentences explaining what you found and the basic impact]

Severity: [Critical/High/Medium/Low]

Steps to Reproduce:
1. [First step with exact URL]
2. [Second step with exact action]
3. [Third step...]
...
X. [Final step showing the vulnerability]

Expected Behavior:
[What should happen in a secure system]

Actual Behavior:
[What actually happens - the vulnerability]

Proof of Concept:
[Screenshots, videos, or code]
[Attach files or provide links]

Impact:
An attacker can exploit this vulnerability to:
- [Specific impact 1]
- [Specific impact 2]
- [Specific impact 3]

Affected Users: [Who is impacted]

Suggested Fix:
[Brief suggestion on how to fix - optional but appreciated]

Additional Notes:
[Any extra relevant information]
```

---

## Article 9: Real Example - Putting It All Together

Let's write a complete report using everything we learned:

```markdown
Title: Stored XSS in Event Description Field Allows Cookie Theft

Summary:
The event creation form does not properly sanitize HTML input in the 
description field. An attacker can create an event with malicious 
JavaScript that executes when any user views the event page, 
potentially stealing session cookies and compromising accounts.

Severity: High

Steps to Reproduce:
1. Log in to https://example.com/login with any account
2. Navigate to https://example.com/events/create
3. Fill in the event details:
   - Title: "Test Event"
   - Date: Any future date
   - Description: <img src=x onerror="alert(document.cookie)">
4. Click "Create Event"
5. Copy the event URL from the success message
6. Log out and log in with a different account (or use incognito mode)
7. Navigate to the event URL copied in step 5
8. Observe the alert box displaying the session cookie

Expected Behavior:
The description field should sanitize or encode HTML/JavaScript input,
preventing script execution. Only plain text or safely rendered HTML 
should be displayed.

Actual Behavior:
The JavaScript payload executes, displaying the session cookie in an 
alert box. This demonstrates that arbitrary JavaScript can be executed 
in the context of any user viewing the event.

Proof of Concept:
[Screenshot 1: Creating event with payload]
[Screenshot 2: Alert box showing cookie on victim's browser]
[Screenshot 3: Browser console showing the executed script]

Request payload:
POST /api/events/create HTTP/1.1
Host: example.com
Cookie: session=attacker_session_token
Content-Type: application/json

{
  "title": "Test Event",
  "date": "2025-11-01",
  "description": "<img src=x onerror=\"alert(document.cookie)\">"
}

Impact:
An attacker can exploit this vulnerability to:
- Steal session cookies of any user who views the malicious event
- Perform actions as the victim (modify profile, create events, etc.)
- Redirect victims to phishing sites to steal credentials
- Deface the event page with malicious content
- Create a worm that spreads the XSS to other events

Affected Users: All users who view public events (estimated 50,000+ users)

Attack Scenario:
1. Attacker creates popular event (free concert, sale event)
2. Users visit the event to see details
3. XSS executes and sends cookies to attacker's server
4. Attacker uses stolen cookies to access victim accounts

Suggested Fix:
- Implement proper input sanitization using a library like DOMPurify
- Apply output encoding when rendering user content
- Use Content Security Policy (CSP) headers
- Consider using a templating engine with auto-escaping
- Implement HTML sanitization on the server-side

Reference: OWASP XSS Prevention Cheat Sheet
https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html

Browser Tested: Chrome 118.0.5993.88
Operating System: Windows 11
Date Discovered: September 30, 2025
```

---

## Article 10: Final Tips for Success

### Before Submitting:
1. ✅ Read the program's policy completely
2. ✅ Check scope carefully
3. ✅ Search for duplicates in disclosed reports
4. ✅ Test your steps one more time
5. ✅ Proofread your report for clarity

### After Submitting:
1. ✅ Be patient for first response
2. ✅ Respond promptly if triager asks questions
3. ✅ Provide additional info if requested
4. ✅ Accept the final decision gracefully
5. ✅ Learn from feedback

### Building Your Reputation:
- Quality over quantity (10 good reports > 100 junk reports)
- Be respectful and professional always
- Help other researchers when you can
- Keep learning and improving
- Celebrate small wins

### Resources for Learning:
- OWASP Top 10
- PortSwigger Web Security Academy
- HackerOne Hacktivity (disclosed reports)
- Bug Bounty writeups on Medium
- PentesterLab exercises

### Remember:
Bug bounty hunting is a marathon, not a sprint. Your first report might get rejected, and that's okay. Every rejection is a learning opportunity. Stay professional, keep learning, and focus on quality.

Good luck with your bug bounty journey! 🎯
```

---

## Quick Reference Checklist

**Before hitting "Submit":**
- [ ] Title is clear and specific
- [ ] Summary explains what and why
- [ ] Steps are numbered and detailed
- [ ] Screenshots/PoC are attached
- [ ] Impact is clearly explained
- [ ] Severity is realistic (not inflated)
- [ ] Language is professional
- [ ] Tested steps work correctly
- [ ] Checked for duplicates
- [ ] Within scope of the program

**Good luck, and happy hunting! 🔒**
