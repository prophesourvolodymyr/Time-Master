import type { ReactNode } from "react";
import clsx from "clsx";
import { CheckIcon, CircleNotchIcon, FileTextIcon, PlusIcon, RobotIcon, SealCheckIcon } from "@phosphor-icons/react";
import { ActionButton, CardSurface, SelectionButton } from "@/components/ui";
import { agentDemo, iconColors, personalities, type Personality } from "./content";
import styles from "./ai-chapter.module.css";

export type AvailabilityState = "idle" | "checking" | "available";

export type AgentDraft = {
  typed: number;
  availability: AvailabilityState;
  color: string | null;
  personality: Personality | null;
  file: boolean;
  pressing: boolean;
};

export const emptyDraft: AgentDraft = {
  typed: 0,
  availability: "idle",
  color: null,
  personality: null,
  file: false,
  pressing: false,
};

export const finishedDraft: AgentDraft = {
  typed: agentDemo.username.length,
  availability: "available",
  color: agentDemo.color,
  personality: agentDemo.personality,
  file: true,
  pressing: false,
};

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className={styles.field}>
      <span className={styles.fieldLabel}>{label}</span>
      {children}
    </div>
  );
}

export function AgentCard({ draft }: { draft: AgentDraft }) {
  const typing = draft.typed > 0 && draft.typed < agentDemo.username.length;
  return (
    <CardSurface className={styles.card} aria-hidden="true" inert>
      <div className={styles.cardHeader}>
        <RobotIcon size={20} weight="fill" aria-hidden="true" />
        <span>New agent</span>
      </div>
      <Field label="Username">
        <div className={styles.input} data-demo-target="username">
          <span className={styles.inputValue}>
            <span className={styles.inputAt}>@</span>
            {draft.typed > 0 ? agentDemo.username.slice(0, draft.typed) : <span className={styles.inputPlaceholder}>pick.a.handle</span>}
            <span className={clsx(styles.caret, typing && styles.caretTyping)} />
          </span>
          {draft.availability === "checking" ? (
            <span className={styles.availability}>
              <CircleNotchIcon size={15} weight="bold" className={styles.spin} aria-hidden="true" />
              Checking
            </span>
          ) : null}
          {draft.availability === "available" ? (
            <span className={clsx(styles.availability, styles.available)}>
              <SealCheckIcon size={16} weight="fill" aria-hidden="true" />
              Available
            </span>
          ) : null}
        </div>
      </Field>
      <Field label="Color">
        <div className={styles.swatches}>
          {iconColors.map((color) => {
            const selected = draft.color === color.hex;
            return (
              <span
                key={color.hex}
                data-demo-target={`color-${color.hex}`}
                data-selected={selected || undefined}
                className={styles.swatch}
                style={{ backgroundColor: color.hex }}
              >
                {selected ? <CheckIcon size={12} weight="bold" color={color.hex === "#FFFFFF" ? "#000" : "#fff"} aria-hidden="true" /> : null}
              </span>
            );
          })}
        </div>
      </Field>
      <Field label="Personality">
        <div className={styles.chips}>
          {personalities.map((personality) => (
            <SelectionButton
              key={personality}
              selected={draft.personality === personality}
              data-demo-target={`personality-${personality}`}
              className={styles.chip}
            >
              {personality}
            </SelectionButton>
          ))}
        </div>
      </Field>
      <Field label="Knowledge file">
        <div className={clsx(styles.file, draft.file && styles.fileAttached)} data-demo-target="file">
          {draft.file ? <FileTextIcon size={18} weight="fill" aria-hidden="true" /> : <PlusIcon size={18} weight="bold" aria-hidden="true" />}
          <span>{draft.file ? agentDemo.knowledgeFile : "Add .txt, .md or .pdf"}</span>
        </div>
      </Field>
      <ActionButton prominent fillsWidth data-demo-target="create" className={clsx(draft.pressing && styles.pressing)}>
        Create agent
      </ActionButton>
    </CardSurface>
  );
}
