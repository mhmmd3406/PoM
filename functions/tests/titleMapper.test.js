'use strict';

const { mapTitleToBusinessFamily } = require('../src/titleMapper');

describe('mapTitleToBusinessFamily', () => {
  // --- IT ---
  test.each([
    ['Senior Software Engineer', 'IT', 'HQ', 'senior'],
    ['Lead Data Scientist', 'IT', 'HQ', 'senior'],
    ['Junior DevOps Engineer', 'IT', 'HQ', 'junior'],
    ['CTO', 'IT', 'HQ', 'exec'],
    ['Chief Information Officer', 'IT', 'HQ', 'exec'],
    ['Cloud Architect', 'IT', 'HQ', 'mid'],
    ['Cybersecurity Analyst', 'IT', 'HQ', 'mid'],
    ['QA Engineer', 'IT', 'HQ', 'mid'],
  ])('%s → %s / %s / %s', (title, family, dept, seniority) => {
    const result = mapTitleToBusinessFamily(title);
    expect(result.businessFamily).toBe(family);
    expect(result.departmentType).toBe(dept);
    expect(result.seniorityLevel).toBe(seniority);
  });

  // --- Treasury/Finance ---
  test.each([
    ['Treasury Manager', 'Treasury/Finance', 'HQ', 'senior'],
    ['Portfolio Manager', 'Treasury/Finance', 'HQ', 'senior'],
    ['CFO', 'Treasury/Finance', 'HQ', 'exec'],
    ['Quantitative Analyst', 'Treasury/Finance', 'HQ', 'mid'],
    ['FX Trader', 'Treasury/Finance', 'HQ', 'mid'],
    ['Financial Controller', 'Treasury/Finance', 'HQ', 'mid'],
  ])('%s → %s / %s / %s', (title, family, dept, seniority) => {
    const result = mapTitleToBusinessFamily(title);
    expect(result.businessFamily).toBe(family);
    expect(result.departmentType).toBe(dept);
    expect(result.seniorityLevel).toBe(seniority);
  });

  // --- Credit/Mkt ---
  test.each([
    ['Credit Analyst', 'Credit/Mkt', 'HQ', 'mid'],
    ['Senior Underwriter', 'Credit/Mkt', 'HQ', 'senior'],
    ['Marketing Manager', 'Credit/Mkt', 'HQ', 'senior'],
    ['Digital Marketing Specialist', 'Credit/Mkt', 'HQ', 'senior'],
    ['Corporate Banking Director', 'Credit/Mkt', 'HQ', 'exec'],
  ])('%s → %s / %s / %s', (title, family, dept, seniority) => {
    const result = mapTitleToBusinessFamily(title);
    expect(result.businessFamily).toBe(family);
    expect(result.departmentType).toBe(dept);
    expect(result.seniorityLevel).toBe(seniority);
  });

  // --- Legal/Other ---
  test.each([
    ['Legal Counsel', 'Legal/Other', 'HQ', 'mid'],
    ['Senior HR Business Partner', 'Legal/Other', 'HQ', 'senior'],
    ['Head of Compliance', 'Legal/Other', 'HQ', 'exec'],
    ['AML Analyst', 'Legal/Other', 'HQ', 'mid'],
    ['Talent Acquisition Specialist', 'Legal/Other', 'HQ', 'senior'],
  ])('%s → %s / %s / %s', (title, family, dept, seniority) => {
    const result = mapTitleToBusinessFamily(title);
    expect(result.businessFamily).toBe(family);
    expect(result.departmentType).toBe(dept);
    expect(result.seniorityLevel).toBe(seniority);
  });

  // --- Branch: Sales/Mkt ---
  test.each([
    ['Relationship Manager', 'Sales/Mkt', 'Branch', 'senior'],
    ['Senior Client Advisor', 'Sales/Mkt', 'Branch', 'senior'],
    ['Mortgage Advisor', 'Sales/Mkt', 'Branch', 'mid'],
    ['Branch Sales Officer', 'Sales/Mkt', 'Branch', 'mid'],
    ['Private Banker', 'Sales/Mkt', 'Branch', 'mid'],
  ])('%s → %s / %s / %s', (title, family, dept, seniority) => {
    const result = mapTitleToBusinessFamily(title);
    expect(result.businessFamily).toBe(family);
    expect(result.departmentType).toBe(dept);
    expect(result.seniorityLevel).toBe(seniority);
  });

  // --- Branch: Ops ---
  test.each([
    ['Branch Manager', 'Ops', 'Branch', 'senior'],
    ['Teller', 'Ops', 'Branch', 'mid'],
    ['Customer Service Officer', 'Ops', 'Branch', 'mid'],
    ['Branch Operations Supervisor', 'Ops', 'Branch', 'senior'],
  ])('%s → %s / %s / %s', (title, family, dept, seniority) => {
    const result = mapTitleToBusinessFamily(title);
    expect(result.businessFamily).toBe(family);
    expect(result.departmentType).toBe(dept);
    expect(result.seniorityLevel).toBe(seniority);
  });

  // --- Turkish titles (critical for TR banking market) ---
  test.each([
    // IT
    ['Yazılım Mühendisi', 'IT', 'HQ', 'mid'],
    ['Kıdemli Veri Bilimci', 'IT', 'HQ', 'senior'],
    ['Siber Güvenlik Uzmanı', 'IT', 'HQ', 'senior'],
    ['Bilgi İşlem Müdürü', 'IT', 'HQ', 'senior'],
    ['Dijital Dönüşüm Direktörü', 'IT', 'HQ', 'exec'],
    // Treasury/Finance
    ['Portföy Yönetmeni', 'Treasury/Finance', 'HQ', 'senior'],
    ['Hazine Müdürü', 'Treasury/Finance', 'HQ', 'senior'],
    ['Kıdemli Finansal Analist', 'Treasury/Finance', 'HQ', 'senior'],
    ['Sermaye Piyasaları Uzmanı', 'Treasury/Finance', 'HQ', 'senior'],
    // Credit/Mkt
    ['Kredi Analisti', 'Credit/Mkt', 'HQ', 'mid'],
    ['Kıdemli Kredi Yöneticisi', 'Credit/Mkt', 'HQ', 'senior'],
    ['Pazarlama Müdürü', 'Credit/Mkt', 'HQ', 'senior'],
    ['Kurumsal Bankacılık Direktörü', 'Credit/Mkt', 'HQ', 'exec'],
    // Legal/Other — Müfettiş is the critical one
    ['Müfettiş', 'Legal/Other', 'HQ', 'mid'],
    ['Başmüfettiş', 'Legal/Other', 'HQ', 'senior'],
    ['İç Denetçi', 'Legal/Other', 'HQ', 'mid'],
    ['Uyum Yöneticisi', 'Legal/Other', 'HQ', 'senior'],
    ['Hukuk Müşaviri', 'Legal/Other', 'HQ', 'mid'],
    ['İnsan Kaynakları Müdürü', 'Legal/Other', 'HQ', 'senior'],
    // Branch Sales
    ['Müşteri İlişkileri Yöneticisi', 'Sales/Mkt', 'Branch', 'senior'],
    ['Bireysel Bankacılık Danışmanı', 'Sales/Mkt', 'Branch', 'mid'],
    ['Özel Bankacı', 'Sales/Mkt', 'Branch', 'mid'],
    ['Finansal Danışman', 'Sales/Mkt', 'Branch', 'mid'],
    // Branch Ops
    ['Şube Müdürü', 'Ops', 'Branch', 'senior'],
    ['Veznedar', 'Ops', 'Branch', 'mid'],
    ['Müşteri Hizmetleri Personeli', 'Ops', 'Branch', 'junior'],
    // Turkish seniority
    ['Kıdemli Müfettiş', 'Legal/Other', 'HQ', 'senior'],
    ['Genel Müdür', 'Legal/Other', 'HQ', 'exec'],
    ['Stajyer Yazılım Geliştirici', 'IT', 'HQ', 'junior'],
  ])('TR: %s → %s / %s / %s', (title, family, dept, seniority) => {
    const result = mapTitleToBusinessFamily(title);
    expect(result.businessFamily).toBe(family);
    expect(result.departmentType).toBe(dept);
    expect(result.seniorityLevel).toBe(seniority);
  });

  // --- Edge cases ---
  test('empty string falls back to Legal/Other HQ', () => {
    expect(mapTitleToBusinessFamily('').businessFamily).toBe('Legal/Other');
  });

  test('null falls back to Legal/Other HQ', () => {
    expect(mapTitleToBusinessFamily(null).businessFamily).toBe('Legal/Other');
  });

  test('completely unknown title falls back to Legal/Other HQ mid', () => {
    const r = mapTitleToBusinessFamily('Grand Poobah of Things');
    expect(r.businessFamily).toBe('Legal/Other');
    expect(r.departmentType).toBe('HQ');
    expect(r.seniorityLevel).toBe('mid');
  });

  test('case-insensitive matching', () => {
    expect(mapTitleToBusinessFamily('SENIOR SOFTWARE ENGINEER').businessFamily).toBe('IT');
  });
});
