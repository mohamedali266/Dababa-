import type { AppLocale } from "./routing";

const numberFormatters = new Map<string, Intl.NumberFormat>();
const dateFormatters = new Map<string, Intl.DateTimeFormat>();

function formatterKey(locale: AppLocale, options: Intl.NumberFormatOptions | Intl.DateTimeFormatOptions) {
  return `${locale}:${JSON.stringify(options)}`;
}

export function formatNumber(locale: AppLocale, value: number, options: Intl.NumberFormatOptions = {}) {
  const key = formatterKey(locale, options);
  const formatter =
    numberFormatters.get(key) ??
    new Intl.NumberFormat(`${locale}-EG-u-nu-latn`, {
      maximumFractionDigits: 2,
      ...options,
    });
  numberFormatters.set(key, formatter);
  return formatter.format(value);
}

export function formatDate(locale: AppLocale, value: Date | string, options: Intl.DateTimeFormatOptions = {}) {
  const key = formatterKey(locale, options);
  const formatter =
    dateFormatters.get(key) ??
    new Intl.DateTimeFormat(`${locale}-EG-u-nu-latn`, {
      day: "2-digit",
      month: "short",
      timeZone: "Africa/Cairo",
      year: "numeric",
      ...options,
    });
  dateFormatters.set(key, formatter);
  return formatter.format(typeof value === "string" ? new Date(value) : value);
}
