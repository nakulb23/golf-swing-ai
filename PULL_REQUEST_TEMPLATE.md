# Pull Request Template

## 🎯 Purpose
Brief description of what this PR accomplishes.

## 🔧 Changes Made
- [ ] List specific files changed
- [ ] Describe functional changes
- [ ] Note any new dependencies
- [ ] Document any breaking changes

## ✅ Testing Checklist
- [ ] App builds successfully (`./test_build.sh`)
- [ ] No Swift compilation errors (`./test_compile.sh`)
- [ ] Manual testing completed in Xcode simulator
- [ ] No new compiler warnings
- [ ] Core features still work (login, camera, etc.)
- [ ] No crashes during basic app flow

### Ball Tracking & Club Analysis Testing (if applicable)
- [ ] Ball tracking completes without memory issues (test with 5-10 second videos)
- [ ] Manual ball selection fallback works when automatic detection fails
- [ ] Trajectory analysis produces valid metrics (launch angle, speed, height)
- [ ] Club analysis detects club face angle and speed correctly
- [ ] Club analysis fallback works when pose detection is incomplete
- [ ] Video compression and frame extraction work efficiently
- [ ] No crashes during intensive video processing
- [ ] Core ML model loading works (with and without model files)

## 🚨 Risk Assessment
- [ ] Low risk - minor UI changes, documentation
- [ ] Medium risk - new feature, refactoring
- [ ] High risk - changes to authentication, camera, core services
- [ ] Very high risk - changes to ball tracking, club analysis, video processing, Core ML integration

## 🎬 Demo/Screenshots
(If applicable, add screenshots or describe what changed visually)

## 📝 Notes
Any additional context, concerns, or follow-up items.

---

**For Claude AI:** 
- Always fill out this template when creating PRs
- Test thoroughly before submitting
- Be honest about risk level