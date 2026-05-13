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
