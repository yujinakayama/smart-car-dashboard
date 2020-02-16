import { RawData } from './rawData';
import { BaseNormalizedData } from './normalizedData';

// We want to extend NormalizedData but it's not allowed
export interface Item extends BaseNormalizedData {
    raw: RawData;
}
