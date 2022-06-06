import { Attachments } from './inputData'
import { BaseNormalizedData } from './normalizedData'

// We want to extend NormalizedData but it's not allowed
export interface Item extends BaseNormalizedData {
    hasBeenOpened: boolean;
    raw: Attachments;
}
