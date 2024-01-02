export function convertAlphanumericsToASCII(text: string | null | undefined): string | null {
  if (!text) {
    return null
  }

  const replaced = text.replace(/[Ａ-Ｚａ-ｚ０-９]/g, (character) => {
    return String.fromCharCode(character.charCodeAt(0) - 65248)
  })

  return replaced.replace(/−/g, '-')
}
