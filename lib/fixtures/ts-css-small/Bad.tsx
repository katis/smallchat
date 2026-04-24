import styles from "./Button.module.css";

export function BrokenBadge(props: { label: string }) {
  return <span class={styles.doesNotExist}>{props.label}</span>;
}
