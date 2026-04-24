import styles from "./Button.module.css";

type Variant = "primary" | "secondary";

export function Button(props: { variant: Variant; label: string }) {
  const cls = props.variant === "primary" ? styles.primary : styles.secondary;
  return <button class={cls}>{props.label}</button>;
}
