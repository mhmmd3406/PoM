import styles from './Header.module.css';

export default function Header({ year, month }) {
  const period = new Date(year, month - 1, 1).toLocaleString('en-GB', {
    month: 'long', year: 'numeric',
  });

  return (
    <header className={styles.header}>
      <div className={styles.inner}>
        <div className={styles.brand}>
          <span className={styles.logo}>✦</span>
          <span className={styles.name}>PoM</span>
          <span className={styles.tag}>B2B Executive Dashboard</span>
        </div>
        <div className={styles.meta}>
          <span className={styles.period}>{period}</span>
          <span className={styles.badge}>Live</span>
        </div>
      </div>
    </header>
  );
}
