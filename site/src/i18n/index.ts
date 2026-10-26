import { en } from './en';
import { ja } from './ja';

export type { Dict } from './ja';
export type Locale = 'ja' | 'en';

export const dictionaries = { ja, en } as const;
