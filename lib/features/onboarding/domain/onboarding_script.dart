// The `OnboardingProgress` field each survey answer writes — the names the
// survey hands `OnboardingCubit.answer`. They match the wire names.
//
// The survey itself is three bespoke cards (`survey_step.dart`): a text field,
// a bar meter and a row of round options no longer share a renderer, so the
// questions live with their widgets rather than in a list here.

const String fieldName = 'name';
const String fieldBand = 'screenTimeBand';
const String fieldMattersMost = 'mattersMost';
