import { useState } from 'react';
import styles from './PrivacyCell.module.css';

export default function PrivacyCell() {
  const [showTip, setShowTip] = useState(false);

  return (
    <span
      className={styles.wrap}
      onMouseEnter={() => setShowTip(true)}
      onMouseLeave={() => setShowTip(false)}
      aria-label="Data anonymized — fewer than 7 responses"
    >
      <span className={styles.blurred} aria-hidden>4.2</span>
      <span className={styles.icon}>🔒</span>
      {showTip && (
        <span className={styles.tooltip} role="tooltip">
          <strong>Your Privacy is Protected</strong>
          <span>At least 7 responses required to display scores. Invite colleagues to unlock.</span>
        </span>
      )}
    </span>
  );
}
