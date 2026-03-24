#!/usr/bin/env bash
# Shared NotebookLM UI knowledge for browser automation scripts.
#
# Purpose:
# - Centralize text patterns that drift when NotebookLM UI changes
# - Make add/create flows update from one place instead of many scripts
#
# Notes:
# - These are broad regexes on purpose: NotebookLM is a SPA and often tweaks
#   wording without changing the underlying action.
# - "Add source" flow may either open a source picker first or jump directly to
#   the URL textbox. Scripts should treat this as a goal-driven flow, not a
#   fixed click sequence.

NOTEBOOKLM_ADD_SOURCE_PATTERN='button.*(添加来源|新增来源|Add source|Add sources|Sources)'
NOTEBOOKLM_WEBSITE_PATTERN='button.*(网站|Website|网页)'
NOTEBOOKLM_URL_INPUT_PATTERN='textbox.*(输入网址|输入多个网址|网址|URL|Enter URL|Paste|paste|link|链接)'
NOTEBOOKLM_INSERT_PATTERN='button.*(插入|Insert|添加|Add)'
NOTEBOOKLM_NEW_NOTEBOOK_PATTERN='button.*(新建笔记本|新建|New notebook|Create new)'

# Operational assumptions used by doctor/troubleshooting docs:
# 1. Opening NotebookLM through playwright-cli must not redirect stdout/stderr
#    to /dev/null, otherwise page readiness can become flaky.
# 2. playwright-cli and patchright must not hold the same browser profile at
#    the same time. If they do, ProcessSingleton/SingletonLock errors are
#    expected rather than surprising.
# 3. A missing button match is more likely to mean UI drift or the wrong dialog
#    state than a total NotebookLM outage.
