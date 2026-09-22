import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";

const EMPTY_COSPEAKER = () => ({
  email: "",
  name: "",
  pronouns: "",
  affiliation: "",
  username: "",
  headshotFile: null,
  headshotUrl: "",
  bio: "",
  inPerson: "",
  travelSponsorship: "",
  visa: "",
  homeAirport: "",
});

const CFP_RECIPIENT_GROUP = "Ubuntu-Summit-Core";

export default apiInitializer("1.8", (api) => {
  class UbuntuSummitCfp extends Component {
    @tracked currentStep = 1;
    @tracked submissionSuccess = false;
    @tracked isSubmitting = false;
    @tracked speakerEmail = "";
    @tracked speakerName = "";
    @tracked speakerPronouns = "";
    @tracked speakerAffiliation = "";
    @tracked speakerUsername = "";
    @tracked speakerHeadshotFile = null;
    @tracked speakerHeadshotUrl = "";
    @tracked talkTitle = "";
    @tracked talkAbstract = "";
    @tracked sessionType = "";
    @tracked difficulty = "";
    @tracked speakerBio = "";
    @tracked presentationLink = "";
    @tracked unconferenceSlot = "";
    @tracked unconferenceIdea = "";
    @tracked inPersonAttendance = "";
    @tracked accommodations = "";
    @tracked travelSponsorship = "";
    @tracked visa = "";
    @tracked homeAirport = "";
    @tracked coSpeakers = [
      EMPTY_COSPEAKER(),
      EMPTY_COSPEAKER(),
      EMPTY_COSPEAKER(),
      EMPTY_COSPEAKER(),
    ];
    @tracked includeCoSpeakers = [false, false, false, false];
    @tracked privacyAgreement = false;

    constructor(...args) {
      super(...args);
      const user = this.currentUser;
      this.speakerName = user?.name || user?.username || "";
      this.speakerEmail = user?.email || "";
      this.speakerUsername = user?.username || "";
    }

    get currentUser() {
      return api.getCurrentUser();
    }

    get isCfpCategory() {
      return window.location.pathname.includes("/c/ubuntu-summit");
    }

    get stepLabels() {
      return [
        { number: 1, label: "Speaker" },
        { number: 2, label: "Session Details" },
        { number: 3, label: "Unconference" },
        { number: 4, label: "Speaker needs" },
        { number: 5, label: "Co-speaker 1" },
        { number: 6, label: "Co-speaker 2" },
        { number: 7, label: "Co-speaker 3" },
        { number: 8, label: "Privacy and review" },
      ];
    }

    get currentCoSpeakerIndex() {
      return this.currentStep - 5;
    }

    get currentCoSpeaker() {
      return this.coSpeakers[this.currentCoSpeakerIndex];
    }

    get includeCurrentCoSpeaker() {
      return this.includeCoSpeakers[this.currentCoSpeakerIndex];
    }

    get nextCoSpeakerIndex() {
      return this.currentCoSpeakerIndex + 1;
    }

    get includeNextCoSpeaker() {
      return this.includeCoSpeakers[this.currentCoSpeakerIndex + 1];
    }

    @action
    togglePrivacy(event) {
      this.privacyAgreement = event.target.checked;
    }

    get submitText() {
      return this.isSubmitting ? "Submitting..." : "Submit proposal";
    }

    get canContinue() {
      if (this.currentStep === 1) {
        return Boolean(this.speakerEmail.trim() && this.speakerName.trim() && this.speakerBio.trim());
      }
      if (this.currentStep === 2) {
        return Boolean(
          this.talkTitle.trim() &&
            this.talkAbstract.trim() &&
            this.sessionType &&
            this.difficulty
        );
      }
      if (this.currentStep === 3) {
        return Boolean(this.unconferenceSlot);
      }
      if (this.currentStep === 4) {
        return Boolean(this.inPersonAttendance);
      }
      if (this.currentStep >= 5 && this.currentStep <= 7) {
        const index = this.currentStep - 5;
        const speaker = this.coSpeakers[index];
        return !this.includeCoSpeakers[index] || Boolean(speaker.name.trim() && speaker.email.trim());
      }
      return this.privacyAgreement;
    }

    @action
    updateField(event) {
      this[event.currentTarget.dataset.field] = event.currentTarget.value;
    }

    @action
    updatePrimaryHeadshot(event) {
      this.speakerHeadshotFile = event.currentTarget.files[0] || null;
    }

    @action
    updateCoSpeaker(event) {
      const index = Number(event.currentTarget.dataset.index);
      const field = event.currentTarget.dataset.field;
      const speakers = this.coSpeakers.map((speaker) => ({ ...speaker }));
      speakers[index][field] = event.currentTarget.value;
      this.coSpeakers = speakers;
    }

    @action
    updateCoSpeakerHeadshot(event) {
      const index = Number(event.currentTarget.dataset.index);
      const speakers = this.coSpeakers.map((speaker) => ({ ...speaker }));
      speakers[index].headshotFile = event.currentTarget.files[0] || null;
      this.coSpeakers = speakers;
    }

    @action
    toggleCoSpeaker(event) {
      const index = Number(event.currentTarget.dataset.index);
      const included = [...this.includeCoSpeakers];
      included[index] = event.currentTarget.checked;
      this.includeCoSpeakers = included;
    }

    @action
    nextStep() {
      if (this.canContinue && this.currentStep < 8) {
        this.currentStep += 1;
      }
    }

    @action
    previousStep() {
      if (this.currentStep > 1) {
        this.currentStep -= 1;
      }
    }

    @action
    showLogin() {
      Discourse.__container__.lookup("route:application")?.send("showLogin");
    }

    async uploadHeadshot(file) {
      if (!file) {
        return null;
      }

      const formData = new FormData();
      formData.append("type", "composer");
      formData.append("file", file);
      formData.append("synchronous", "true");

      const response = await ajax("/uploads.json", {
        type: "POST",
        data: formData,
        processData: false,
        contentType: false,
      });

      return response.url.startsWith("http")
        ? response.url
        : window.location.origin + response.url;
    }

    buildSpeakerMarkdown(title, speaker) {
      return `### ${title}\n` +
        `* **Email:** ${speaker.email || "Not provided"}\n` +
        `* **Name:** ${speaker.name || "Not provided"}\n` +
        `* **Pronouns:** ${speaker.pronouns || "Not provided"}\n` +
        `* **Affiliation:** ${speaker.affiliation || "Not provided"}\n` +
        `* **Discourse username:** ${speaker.username || "Not provided"}\n` +
        `* **Headshot:** ${speaker.headshotUrl || "Not provided"}\n` +
        `* **Bio:** ${speaker.bio || "Not provided"}\n` +
        `* **In-person attendance:** ${speaker.inPerson || "Not provided"}\n` +
        `* **Travel sponsorship:** ${speaker.travelSponsorship || "Not provided"}\n` +
        `* **UK Visa/ETA:** ${speaker.visa || "Not provided"}\n` +
        `* **Home airport:** ${speaker.homeAirport || "Not provided"}\n\n`;
    }

    buildPrimarySpeakerMarkdown(headshotUrl) {
      return `### Primary speaker\n` +
        `* **Email:** ${this.speakerEmail || "Not provided"}\n` +
        `* **Name:** ${this.speakerName || "Not provided"}\n` +
        `* **Pronouns:** ${this.speakerPronouns || "Not provided"}\n` +
        `* **Affiliation:** ${this.speakerAffiliation || "Not provided"}\n` +
        `* **Discourse username:** ${this.speakerUsername || "Not provided"}\n` +
        `* **Headshot:** ${headshotUrl || "Not provided"}\n` +
        `* **Bio:** ${this.speakerBio || "Not provided"}\n\n`;
    }

    @action
    async submitCfpForm(event) {
      event.preventDefault();
      if (!this.canContinue) {
        return;
      }
      this.isSubmitting = true;
      try {
        const uploadedPrimaryHeadshot = await this.uploadHeadshot(
          this.speakerHeadshotFile
        );
        const uploadedCoSpeakerHeadshots = await Promise.all(
          this.coSpeakers.map((speaker) =>
            this.uploadHeadshot(speaker.headshotFile)
          )
        );

        this.speakerHeadshotUrl = uploadedPrimaryHeadshot || "";
        this.coSpeakers = this.coSpeakers.map((speaker, index) => ({
          ...speaker,
          headshotUrl: uploadedCoSpeakerHeadshots[index] || "",
        }));

        let markdownBody = "## New Ubuntu Summit CFP Proposal\n\n";
        markdownBody += this.buildPrimarySpeakerMarkdown(uploadedPrimaryHeadshot);
        markdownBody += "### Session\n";
        markdownBody += `* **Title:** ${this.talkTitle || "Not provided"}\n`;
        markdownBody += `* **Session type:** ${this.sessionType || "Not provided"}\n`;
        markdownBody += `* **Difficulty:** ${this.difficulty || "Not provided"}\n`;
        markdownBody += `* **Google Slides/BYOD:** ${this.presentationLink || "Not provided"}\n`;
        markdownBody += `**Abstract:**\n${this.talkAbstract || "Not provided"}\n\n`;
        markdownBody += `### Unconference\n* **Would you like an unconference slot?:** ${this.unconferenceSlot}\n* **Idea:** ${this.unconferenceIdea || "Not provided"}\n\n`;
        markdownBody += `### Speaker needs\n* **In-person attendance:** ${this.inPersonAttendance}\n* **Accommodations:** ${this.accommodations || "None"}\n`;
        markdownBody += `* **Travel sponsorship:** ${this.travelSponsorship}\n* **UK Visa/ETA:** ${this.visa}\n* **Home airport:** ${this.homeAirport}\n\n`;
        this.coSpeakers.forEach((speaker, index) => {
          if (this.includeCoSpeakers[index]) {
            markdownBody += this.buildSpeakerMarkdown(
              `Co-speaker ${index + 1}`,
              speaker
            );
          }
        });
        markdownBody += `### Privacy and review\n* **Privacy notice accepted:** ${this.privacyAgreement ? "Yes" : "No"}\n`;
        markdownBody += "I confirm that I have reviewed this proposal and agree to the privacy notice.\n";

        await ajax("/posts.json", {
          type: "POST",
          data: {
            title: `[CFP Submission] ${this.talkTitle}`,
            raw: markdownBody,
            archetype: "private_message",
            target_recipients: CFP_RECIPIENT_GROUP,
          },
        });
        this.submissionSuccess = true;
      } catch (error) {
        popupAjaxError(error);
      } finally {
        this.isSubmitting = false;
      }
    }

    <template>
      {{#if this.isCfpCategory}}
        <div class="ubuntu-cfp-container">
          {{#if this.currentUser}}
            {{#if this.submissionSuccess}}
              <div class="cfp-success-view"><h2>Thank you for submitting your talk!</h2><p>The Ubuntu Summit Organizing Team has received your proposal.</p></div>
            {{else}}
              <h2>Ubuntu Summit - Call for Papers</h2>
              <p>Complete the eight steps below. Required fields must be completed before continuing.</p>
              <div class="cfp-stepper" aria-label="Proposal progress">
                {{#each this.stepLabels as |step|}}<span class={{if (eq this.currentStep step.number) "active"}}>{{step.number}}. {{step.label}}</span>{{/each}}
              </div>
              <form {{on "submit" this.submitCfpForm}}>
                {{#if (eq this.currentStep 1)}}
                  <fieldset class="cfp-step-content">
                    <legend>Primary Speaker</legend>
                    <div class="cfp-field">
                        <label for="cfp-s1-name">Name / Handle</label>
                        <input type="text" id="cfp-s1-name" value={{this.speakerName}} data-field="speakerName" class="cfp-input" {{on "input" this.updateField}} required />
                    </div>
                    <div class="cfp-field">
                        <label for="cfp-email">Account Email</label>
                        <input type="email" id="cfp-email" value={{this.speakerEmail}} data-field="speakerEmail" class="cfp-input" {{on "input" this.updateField}} required />
                    </div>
                    <div class="cfp-field">
                        <label for="cfp-s1-affil">Affiliation / Company (Optional)</label>
                        <input type="text" id="cfp-s1-affil" value={{this.speakerAffiliation}} data-field="speakerAffiliation" {{on "input" this.updateField}} placeholder="e.g., Canonical" class="cfp-input" />
                    </div>
                    <div class="cfp-field">
                        <label>Speaker Headshot (Optional)</label>
                        <input type="file" id="cfp-s1-photo" accept="image/png, image/jpeg, image/webp" class="cfp-input" style="padding: 10px 0;" {{on "change" this.updatePrimaryHeadshot}} />
                        <small style="display: block; margin-top: 5px; color: var(--primary-medium);">If left blank, we will default to your forum profile picture.</small>
                    </div>
                    <div class="cfp-field"><label for="cfp-bio">Bio *</label><textarea id="cfp-bio" class="cfp-input" data-field="speakerBio" {{on "input" this.updateField}} required>{{this.speakerBio}}</textarea></div>
                </fieldset>
                {{else if (eq this.currentStep 2)}}
                   <fieldset class="cfp-step-content">
                    <legend>Session Details</legend>
                    <div class="cfp-field">
                        <label for="cfp-title">Proposed Talk Title</label>
                        <input type="text" id="cfp-title" value={{this.talkTitle}} data-field="talkTitle" {{on "input" this.updateField}} placeholder="e.g., Optimizing Edge Workloads with Ubuntu Core" class="cfp-input" required />
                    </div>
                    <div class="cfp-field">
                        <label for="cfp-abstract">Talk Abstract</label>
                        <textarea id="cfp-abstract" data-field="talkAbstract" {{on "input" this.updateField}} placeholder="Provide a detailed description of your presentation theme, technical level, and key takeaways for attendees..." class="cfp-input" required>{{this.talkAbstract}}</textarea>
                    </div>
                    <div class="cfp-field">
                        <label for="cfp-slides">Presentation Draft / Supporting Materials Link (Optional)</label>
                        <input type="url" id="cfp-slides" value={{this.presentationLink}} data-field="presentationLink" {{on "input" this.updateField}} placeholder="e.g., Link to slide decks, GitHub repos, or shared design drafts..." class="cfp-input" />
                    </div>
                    <div class="cfp-field"><label for="cfp-session-type">Session type *</label><select id="cfp-session-type" class="cfp-input" data-field="sessionType" {{on "change" this.updateField}} required><option value="">Select one</option><option selected={{eq this.sessionType "Talk: 25 minutes"}}>Talk: 25 minutes</option><option selected={{eq this.sessionType "Talk: 45 minutes"}}>Talk: 45 minutes</option><option selected={{eq this.sessionType "Lightning talk: 5 minutes"}}>Lightning talk: 5 minutes</option></select></div>
                    <div class="cfp-field"><label for="cfp-difficulty">Difficulty *</label><select id="cfp-difficulty" class="cfp-input" data-field="difficulty" {{on "change" this.updateField}} required><option value="">Select one</option><option selected={{eq this.difficulty "Beginner"}}>Beginner</option><option selected={{eq this.difficulty "Intermediate"}}>Intermediate</option><option selected={{eq this.difficulty "Advanced"}}>Advanced</option></select></div>
                </fieldset>
                {{else if (eq this.currentStep 3)}}
                  <fieldset class="cfp-step-content"><legend>2. Unconference</legend>
                    <div class="cfp-field"><label for="cfp-unconference">Would you like an unconference slot? *</label><select id="cfp-unconference" class="cfp-input" data-field="unconferenceSlot" {{on "change" this.updateField}} required><option value="">Select one</option><option selected={{eq this.unconferenceSlot "Yes"}}>Yes</option><option selected={{eq this.unconferenceSlot "No"}}>No</option></select></div>
                    <div class="cfp-field"><label for="cfp-unconference-idea">What would you like to discuss?</label><textarea id="cfp-unconference-idea" class="cfp-input" data-field="unconferenceIdea" {{on "input" this.updateField}}>{{this.unconferenceIdea}}</textarea></div>
                  </fieldset>
                {{else if (eq this.currentStep 4)}}
                  <fieldset class="cfp-step-content"><legend>3. Speaker needs</legend>
                    <div class="cfp-field"><label for="cfp-in-person">Will you attend in person? *</label><select id="cfp-in-person" class="cfp-input" data-field="inPersonAttendance" {{on "change" this.updateField}} required><option value="">Select one</option><option selected={{eq this.inPersonAttendance "Yes"}}>Yes</option><option selected={{eq this.inPersonAttendance "No"}}>No</option><option selected={{eq this.inPersonAttendance "Not sure"}}>Not sure</option></select></div>
                    <div class="cfp-field"><label for="cfp-accommodations">Do you need accommodations?</label><textarea id="cfp-accommodations" class="cfp-input" data-field="accommodations" {{on "input" this.updateField}}>{{this.accommodations}}</textarea></div>
                    <div class="cfp-field"><label for="cfp-travel">Do you need travel sponsorship?</label><select id="cfp-travel" class="cfp-input" data-field="travelSponsorship" {{on "change" this.updateField}}><option value="">Select one</option><option selected={{eq this.travelSponsorship "Yes"}}>Yes</option><option selected={{eq this.travelSponsorship "No"}}>No</option></select></div>
                    <div class="cfp-field"><label for="cfp-visa">Do you need a UK Visa/ETA?</label><select id="cfp-visa" class="cfp-input" data-field="visa" {{on "change" this.updateField}}><option value="">Select one</option><option selected={{eq this.visa "Yes"}}>Yes</option><option selected={{eq this.visa "No"}}>No</option><option selected={{eq this.visa "Not sure"}}>Not sure</option></select></div>
                    <div class="cfp-field"><label for="cfp-airport">Home airport</label><input id="cfp-airport" class="cfp-input" type="text" value={{this.homeAirport}} data-field="homeAirport" {{on "input" this.updateField}} /></div>
                  </fieldset>
                {{else if (and (gte this.currentStep 5) (lte this.currentStep 7))}}
                  <fieldset class="cfp-step-content"><legend>{{this.currentStep}}. Co-speaker {{this.currentStep}}</legend>
                    <p>Co-speakers are optional. Select the toggle below to include this speaker.</p>
                    <div class="cfp-field"><label><input type="checkbox" checked={{this.includeCurrentCoSpeaker}} data-index={{this.currentCoSpeakerIndex}} {{on "change" this.toggleCoSpeaker}} /> Include co-speaker {{this.currentStep}}</label></div>
                    <div class="cfp-field"><label>Email <span>(required when included)</span></label><input class="cfp-input" type="email" data-index={{this.currentCoSpeakerIndex}} data-field="email" value={{this.currentCoSpeaker.email}} {{on "input" this.updateCoSpeaker}} /></div>
                    <div class="cfp-field"><label>Name <span>(required when included)</span></label><input class="cfp-input" type="text" data-index={{this.currentCoSpeakerIndex}} data-field="name" value={{this.currentCoSpeaker.name}} {{on "input" this.updateCoSpeaker}} /></div>
                    <div class="cfp-field"><label>Pronouns</label><input class="cfp-input" type="text" data-index={{this.currentCoSpeakerIndex}} data-field="pronouns" value={{this.currentCoSpeaker.pronouns}} {{on "input" this.updateCoSpeaker}} /></div>
                    <div class="cfp-field"><label>Affiliation</label><input class="cfp-input" type="text" data-index={{this.currentCoSpeakerIndex}} data-field="affiliation" value={{this.currentCoSpeaker.affiliation}} {{on "input" this.updateCoSpeaker}} /></div>
                    <div class="cfp-field"><label>Discourse username</label><input class="cfp-input" type="text" data-index={{this.currentCoSpeakerIndex}} data-field="username" value={{this.currentCoSpeaker.username}} {{on "input" this.updateCoSpeaker}} /></div>
                    <div class="cfp-field">
                        <label>Headshot</label>
                        <input type="file" accept="image/png, image/jpeg, image/webp" class="cfp-input" style="padding: 10px 0;" data-index={{this.currentCoSpeakerIndex}} {{on "change" this.updateCoSpeakerHeadshot}} />
                    </div>
                    <div class="cfp-field"><label>Bio</label><textarea class="cfp-input" data-index={{this.currentCoSpeakerIndex}} data-field="bio" {{on "input" this.updateCoSpeaker}}>{{this.currentCoSpeaker.bio}}</textarea></div>
                    <div class="cfp-field"><label>In-person attendance</label><input class="cfp-input" type="text" data-index={{this.currentCoSpeakerIndex}} data-field="inPerson" value={{this.currentCoSpeaker.inPerson}} {{on "input" this.updateCoSpeaker}} /></div>
                    <div class="cfp-field"><label>Travel sponsorship</label><input class="cfp-input" type="text" data-index={{this.currentCoSpeakerIndex}} data-field="travelSponsorship" value={{this.currentCoSpeaker.travelSponsorship}} {{on "input" this.updateCoSpeaker}} /></div>
                    <div class="cfp-field"><label>UK Visa/ETA</label><input class="cfp-input" type="text" data-index={{this.currentCoSpeakerIndex}} data-field="visa" value={{this.currentCoSpeaker.visa}} {{on "input" this.updateCoSpeaker}} /></div>
                    <div class="cfp-field"><label>Home airport</label><input class="cfp-input" type="text" data-index={{this.currentCoSpeakerIndex}} data-field="homeAirport" value={{this.currentCoSpeaker.homeAirport}} {{on "input" this.updateCoSpeaker}} /></div>
                    {{#if (lt this.currentStep 7)}}<div class="cfp-field"><label><input type="checkbox" checked={{this.includeNextCoSpeaker}} data-index={{this.nextCoSpeakerIndex}} {{on "change" this.toggleCoSpeaker}} /> Add next speaker</label></div>{{/if}}
                  </fieldset>
                {{else}}
                  <fieldset class="cfp-step-content"><legend>7. Privacy and review</legend>
                    <p>Review your submission. It will be sent as a private message to the Ubuntu Summit Core team.</p>
                    <div class="cfp-review-box"><strong>{{this.talkTitle}}</strong><p>{{this.talkAbstract}}</p><p>Primary speaker: {{this.speakerName}}</p><p>Unconference: {{this.unconferenceSlot}}</p><p>Co-speakers included: {{this.includeCoSpeakers}}</p></div>
                    <div class="cfp-field"><label><input type="checkbox" checked={{this.privacyAgreement}} {{on "change" this.togglePrivacy}} required /> I agree to the <a href="https://ubuntu.com/legal/data-privacy" target="_blank" rel="noopener noreferrer">Canonical privacy policy and privacy notice</a>, and confirm I have reviewed this proposal. *</label></div>
                  </fieldset>
                {{/if}}
                <div class="cfp-form-actions">{{#if (gt this.currentStep 1)}}<button type="button" class="btn" {{on "click" this.previousStep}}>Back</button>{{/if}}{{#if (lt this.currentStep 8)}}<button type="button" class="btn btn-primary" disabled={{not this.canContinue}} {{on "click" this.nextStep}}>Next</button>{{else}}<button type="submit" class="btn btn-primary" disabled={{or this.isSubmitting (not this.canContinue)}}>{{this.submitText}}</button>{{/if}}</div>
              </form>
            {{/if}}
          {{else}}
            <div class="cfp-login-promo"><h2>Ubuntu Summit Call for Papers Portal</h2><p>You must be logged in to submit a proposal.</p><button type="button" class="btn btn-primary" {{on "click" this.showLogin}}>Log in / register</button></div>
          {{/if}}
        </div>
      {{/if}}
    </template>
  }

  api.renderInOutlet("discovery-list-container-top", UbuntuSummitCfp);
});
