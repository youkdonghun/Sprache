part of 'sample_content.dart';

// Project-authored practical phrases. No external corpus text is included.
// Keep the same semantic order in every language so editorial review can
// compare translations side by side.

const _englishPracticalSentences = <_SentenceSeed>[
  _SentenceSeed('I would like to check in.', '체크인하고 싶어요.', [
    'I would like',
    'to check in.',
  ]),
  _SentenceSeed('Could I see the menu?', '메뉴를 볼 수 있을까요?', [
    'Could I',
    'see',
    'the menu?',
  ]),
  _SentenceSeed('Please take me to this address.', '이 주소로 가 주세요.', [
    'Please',
    'take me',
    'to this address.',
  ]),
  _SentenceSeed('Does this train go downtown?', '이 기차는 시내로 가나요?', [
    'Does this train',
    'go',
    'downtown?',
  ]),
  _SentenceSeed('What time does the store open?', '가게는 몇 시에 열어요?', [
    'What time',
    'does the store',
    'open?',
  ]),
  _SentenceSeed('Where is the restroom?', '화장실은 어디예요?', [
    'Where is',
    'the restroom?',
  ]),
  _SentenceSeed('Can I pay by card?', '카드로 결제할 수 있나요?', [
    'Can I',
    'pay',
    'by card?',
  ]),
  _SentenceSeed('Please give me a receipt.', '영수증을 주세요.', [
    'Please',
    'give me',
    'a receipt.',
  ]),
  _SentenceSeed('I have a food allergy.', '음식 알레르기가 있어요.', [
    'I have',
    'a food allergy.',
  ]),
  _SentenceSeed('Please call an ambulance.', '구급차를 불러 주세요.', [
    'Please',
    'call',
    'an ambulance.',
  ]),
  _SentenceSeed('I lost my passport.', '여권을 잃어버렸어요.', [
    'I lost',
    'my passport.',
  ]),
  _SentenceSeed('Is there Wi-Fi here?', '여기에 와이파이가 있나요?', [
    'Is there',
    'Wi-Fi',
    'here?',
  ]),
  _SentenceSeed('The meeting starts at ten.', '회의는 열 시에 시작해요.', [
    'The meeting',
    'starts',
    'at ten.',
  ]),
  _SentenceSeed('Please send me the file.', '파일을 보내 주세요.', [
    'Please',
    'send me',
    'the file.',
  ]),
  _SentenceSeed('I will call you back later.', '나중에 다시 전화할게요.', [
    'I will',
    'call you back',
    'later.',
  ]),
  _SentenceSeed('I need more time.', '시간이 더 필요해요.', ['I need', 'more time.']),
  _SentenceSeed('Could you repeat that?', '다시 말해 주시겠어요?', [
    'Could you',
    'repeat',
    'that?',
  ]),
  _SentenceSeed('How do you spell this?', '이건 철자가 어떻게 되나요?', [
    'How do you',
    'spell',
    'this?',
  ]),
  _SentenceSeed('What does this word mean?', '이 단어는 무슨 뜻이에요?', [
    'What does',
    'this word',
    'mean?',
  ]),
  _SentenceSeed('I practiced for thirty minutes today.', '오늘 30분 연습했어요.', [
    'I practiced',
    'for thirty minutes',
    'today.',
  ]),
];

const _japanesePracticalSentences = <_SentenceSeed>[
  _SentenceSeed(
    'チェックインをお願いします。',
    '체크인 부탁드립니다.',
    ['チェックインを', 'お願いします。'],
    reading: 'チェックインをおねがいします',
    romanization: 'chekkuin o onegaishimasu',
  ),
  _SentenceSeed(
    'メニューを見せてください。',
    '메뉴를 보여 주세요.',
    ['メニューを', '見せて', 'ください。'],
    reading: 'メニューをみせてください',
    romanization: 'menyuu o misete kudasai',
  ),
  _SentenceSeed(
    'この住所までお願いします。',
    '이 주소까지 가 주세요.',
    ['この住所まで', 'お願いします。'],
    reading: 'このじゅうしょまでおねがいします',
    romanization: 'kono juusho made onegaishimasu',
  ),
  _SentenceSeed(
    'この電車は市内に行きますか。',
    '이 전철은 시내로 가나요?',
    ['この電車は', '市内に', '行きますか。'],
    reading: 'このでんしゃはしないにいきますか',
    romanization: 'kono densha wa shinai ni ikimasu ka',
  ),
  _SentenceSeed(
    '店は何時に開きますか。',
    '가게는 몇 시에 열어요?',
    ['店は', '何時に', '開きますか。'],
    reading: 'みせはなんじにあきますか',
    romanization: 'mise wa nanji ni akimasu ka',
  ),
  _SentenceSeed(
    'トイレはどこですか。',
    '화장실은 어디예요?',
    ['トイレは', 'どこですか。'],
    reading: 'トイレはどこですか',
    romanization: 'toire wa doko desu ka',
  ),
  _SentenceSeed(
    'カードで払えますか。',
    '카드로 결제할 수 있나요?',
    ['カードで', '払えますか。'],
    reading: 'カードではらえますか',
    romanization: 'kaado de haraemasu ka',
  ),
  _SentenceSeed(
    'レシートをください。',
    '영수증을 주세요.',
    ['レシートを', 'ください。'],
    reading: 'レシートをください',
    romanization: 'reshiito o kudasai',
  ),
  _SentenceSeed(
    '食べ物にアレルギーがあります。',
    '음식 알레르기가 있어요.',
    ['食べ物に', 'アレルギーが', 'あります。'],
    reading: 'たべものにアレルギーがあります',
    romanization: 'tabemono ni arerugii ga arimasu',
  ),
  _SentenceSeed(
    '救急車を呼んでください。',
    '구급차를 불러 주세요.',
    ['救急車を', '呼んで', 'ください。'],
    reading: 'きゅうきゅうしゃをよんでください',
    romanization: 'kyuukyuusha o yonde kudasai',
  ),
  _SentenceSeed(
    'パスポートをなくしました。',
    '여권을 잃어버렸어요.',
    ['パスポートを', 'なくしました。'],
    reading: 'パスポートをなくしました',
    romanization: 'pasupooto o nakushimashita',
  ),
  _SentenceSeed(
    'ここにWi-Fiはありますか。',
    '여기에 와이파이가 있나요?',
    ['ここに', 'Wi-Fiは', 'ありますか。'],
    reading: 'ここにワイファイはありますか',
    romanization: 'koko ni waifai wa arimasu ka',
  ),
  _SentenceSeed(
    '会議は10時に始まります。',
    '회의는 열 시에 시작해요.',
    ['会議は', '10時に', '始まります。'],
    reading: 'かいぎはじゅうじにはじまります',
    romanization: 'kaigi wa juuji ni hajimarimasu',
  ),
  _SentenceSeed(
    'ファイルを送ってください。',
    '파일을 보내 주세요.',
    ['ファイルを', '送って', 'ください。'],
    reading: 'ファイルをおくってください',
    romanization: 'fairu o okutte kudasai',
  ),
  _SentenceSeed(
    'あとでかけ直します。',
    '나중에 다시 전화할게요.',
    ['あとで', 'かけ直します。'],
    reading: 'あとでかけなおします',
    romanization: 'ato de kakenaoshimasu',
  ),
  _SentenceSeed(
    'もう少し時間が必要です。',
    '시간이 조금 더 필요해요.',
    ['もう少し', '時間が', '必要です。'],
    reading: 'もうすこしじかんがひつようです',
    romanization: 'mou sukoshi jikan ga hitsuyou desu',
  ),
  _SentenceSeed(
    'もう一度言ってください。',
    '다시 한번 말해 주세요.',
    ['もう一度', '言って', 'ください。'],
    reading: 'もういちどいってください',
    romanization: 'mou ichido itte kudasai',
  ),
  _SentenceSeed(
    'これはどう書きますか。',
    '이것은 어떻게 쓰나요?',
    ['これは', 'どう', '書きますか。'],
    reading: 'これはどうかきますか',
    romanization: 'kore wa dou kakimasu ka',
  ),
  _SentenceSeed(
    'この単語はどういう意味ですか。',
    '이 단어는 무슨 뜻이에요?',
    ['この単語は', 'どういう', '意味ですか。'],
    reading: 'このたんごはどういういみですか',
    romanization: 'kono tango wa dou iu imi desu ka',
  ),
  _SentenceSeed(
    '今日は30分練習しました。',
    '오늘 30분 연습했어요.',
    ['今日は', '30分', '練習しました。'],
    reading: 'きょうはさんじゅっぷんれんしゅうしました',
    romanization: 'kyou wa sanjuppun renshuu shimashita',
  ),
];

const _germanPracticalSentences = <_SentenceSeed>[
  _SentenceSeed('Ich möchte einchecken.', '체크인하고 싶어요.', [
    'Ich möchte',
    'einchecken.',
  ]),
  _SentenceSeed('Könnte ich bitte die Speisekarte sehen?', '메뉴를 볼 수 있을까요?', [
    'Könnte ich',
    'bitte',
    'die Speisekarte sehen?',
  ]),
  _SentenceSeed('Bitte fahren Sie mich zu dieser Adresse.', '이 주소로 데려다 주세요.', [
    'Bitte',
    'fahren Sie mich',
    'zu dieser Adresse.',
  ]),
  _SentenceSeed('Fährt dieser Zug ins Stadtzentrum?', '이 기차는 시내로 가나요?', [
    'Fährt dieser Zug',
    'ins Stadtzentrum?',
  ]),
  _SentenceSeed('Um wie viel Uhr öffnet das Geschäft?', '가게는 몇 시에 열어요?', [
    'Um wie viel Uhr',
    'öffnet',
    'das Geschäft?',
  ]),
  _SentenceSeed('Wo ist die Toilette?', '화장실은 어디예요?', [
    'Wo ist',
    'die Toilette?',
  ]),
  _SentenceSeed('Kann ich mit Karte bezahlen?', '카드로 결제할 수 있나요?', [
    'Kann ich',
    'mit Karte',
    'bezahlen?',
  ]),
  _SentenceSeed('Bitte geben Sie mir eine Quittung.', '영수증을 주세요.', [
    'Bitte',
    'geben Sie mir',
    'eine Quittung.',
  ]),
  _SentenceSeed('Ich habe eine Lebensmittelallergie.', '음식 알레르기가 있어요.', [
    'Ich habe',
    'eine Lebensmittelallergie.',
  ]),
  _SentenceSeed('Rufen Sie bitte einen Krankenwagen.', '구급차를 불러 주세요.', [
    'Rufen Sie',
    'bitte',
    'einen Krankenwagen.',
  ]),
  _SentenceSeed('Ich habe meinen Reisepass verloren.', '여권을 잃어버렸어요.', [
    'Ich habe',
    'meinen Reisepass',
    'verloren.',
  ]),
  _SentenceSeed('Gibt es hier WLAN?', '여기에 와이파이가 있나요?', [
    'Gibt es',
    'hier',
    'WLAN?',
  ]),
  _SentenceSeed('Die Besprechung beginnt um zehn Uhr.', '회의는 열 시에 시작해요.', [
    'Die Besprechung',
    'beginnt',
    'um zehn Uhr.',
  ]),
  _SentenceSeed('Bitte schicken Sie mir die Datei.', '파일을 보내 주세요.', [
    'Bitte',
    'schicken Sie mir',
    'die Datei.',
  ]),
  _SentenceSeed('Ich rufe Sie später zurück.', '나중에 다시 전화할게요.', [
    'Ich rufe Sie',
    'später',
    'zurück.',
  ]),
  _SentenceSeed('Ich brauche mehr Zeit.', '시간이 더 필요해요.', [
    'Ich brauche',
    'mehr Zeit.',
  ]),
  _SentenceSeed('Könnten Sie das bitte wiederholen?', '다시 말해 주시겠어요?', [
    'Könnten Sie',
    'das bitte',
    'wiederholen?',
  ]),
  _SentenceSeed('Wie schreibt man das?', '이건 철자가 어떻게 되나요?', [
    'Wie schreibt',
    'man das?',
  ]),
  _SentenceSeed('Was bedeutet dieses Wort?', '이 단어는 무슨 뜻이에요?', [
    'Was bedeutet',
    'dieses Wort?',
  ]),
  _SentenceSeed('Ich habe heute dreißig Minuten geübt.', '오늘 30분 연습했어요.', [
    'Ich habe',
    'heute',
    'dreißig Minuten geübt.',
  ]),
];

const _frenchPracticalSentences = <_SentenceSeed>[
  _SentenceSeed('Je voudrais m’enregistrer, s’il vous plaît.', '체크인하고 싶어요.', [
    'Je voudrais',
    'm’enregistrer,',
    's’il vous plaît.',
  ]),
  _SentenceSeed('Pourrais-je voir le menu ?', '메뉴를 볼 수 있을까요?', [
    'Pourrais-je',
    'voir',
    'le menu ?',
  ]),
  _SentenceSeed('Veuillez m’emmener à cette adresse.', '이 주소로 데려다 주세요.', [
    'Veuillez',
    'm’emmener',
    'à cette adresse.',
  ]),
  _SentenceSeed('Ce train va-t-il au centre-ville ?', '이 기차는 시내로 가나요?', [
    'Ce train',
    'va-t-il',
    'au centre-ville ?',
  ]),
  _SentenceSeed('À quelle heure le magasin ouvre-t-il ?', '가게는 몇 시에 열어요?', [
    'À quelle heure',
    'le magasin',
    'ouvre-t-il ?',
  ]),
  _SentenceSeed('Où sont les toilettes ?', '화장실은 어디예요?', [
    'Où sont',
    'les toilettes ?',
  ]),
  _SentenceSeed('Puis-je payer par carte ?', '카드로 결제할 수 있나요?', [
    'Puis-je',
    'payer',
    'par carte ?',
  ]),
  _SentenceSeed('Un reçu, s’il vous plaît.', '영수증을 주세요.', [
    'Un reçu,',
    's’il vous plaît.',
  ]),
  _SentenceSeed('J’ai une allergie alimentaire.', '음식 알레르기가 있어요.', [
    'J’ai',
    'une allergie alimentaire.',
  ]),
  _SentenceSeed('Appelez une ambulance, s’il vous plaît.', '구급차를 불러 주세요.', [
    'Appelez',
    'une ambulance,',
    's’il vous plaît.',
  ]),
  _SentenceSeed('J’ai perdu mon passeport.', '여권을 잃어버렸어요.', [
    'J’ai perdu',
    'mon passeport.',
  ]),
  _SentenceSeed('Est-ce qu’il y a du Wi-Fi ici ?', '여기에 와이파이가 있나요?', [
    'Est-ce qu’il y a',
    'du Wi-Fi',
    'ici ?',
  ]),
  _SentenceSeed('La réunion commence à dix heures.', '회의는 열 시에 시작해요.', [
    'La réunion',
    'commence',
    'à dix heures.',
  ]),
  _SentenceSeed('Envoyez-moi le fichier, s’il vous plaît.', '파일을 보내 주세요.', [
    'Envoyez-moi',
    'le fichier,',
    's’il vous plaît.',
  ]),
  _SentenceSeed('Je vous rappellerai plus tard.', '나중에 다시 전화할게요.', [
    'Je vous rappellerai',
    'plus tard.',
  ]),
  _SentenceSeed('J’ai besoin de plus de temps.', '시간이 더 필요해요.', [
    'J’ai besoin',
    'de plus de temps.',
  ]),
  _SentenceSeed('Pourriez-vous répéter, s’il vous plaît ?', '다시 말해 주시겠어요?', [
    'Pourriez-vous',
    'répéter,',
    's’il vous plaît ?',
  ]),
  _SentenceSeed('Comment cela s’écrit-il ?', '이건 철자가 어떻게 되나요?', [
    'Comment',
    'cela',
    's’écrit-il ?',
  ]),
  _SentenceSeed('Que signifie ce mot ?', '이 단어는 무슨 뜻이에요?', [
    'Que signifie',
    'ce mot ?',
  ]),
  _SentenceSeed(
    'J’ai étudié pendant trente minutes aujourd’hui.',
    '오늘 30분 공부했어요.',
    ['J’ai étudié', 'pendant trente minutes', 'aujourd’hui.'],
  ),
];

const _spanishPracticalSentences = <_SentenceSeed>[
  _SentenceSeed('Quisiera registrarme.', '체크인하고 싶어요.', [
    'Quisiera',
    'registrarme.',
  ]),
  _SentenceSeed('¿Podría ver el menú?', '메뉴를 볼 수 있을까요?', [
    '¿Podría',
    'ver',
    'el menú?',
  ]),
  _SentenceSeed('Lléveme a esta dirección, por favor.', '이 주소로 데려다 주세요.', [
    'Lléveme',
    'a esta dirección,',
    'por favor.',
  ]),
  _SentenceSeed('¿Este tren va al centro?', '이 기차는 시내로 가나요?', [
    '¿Este tren',
    'va',
    'al centro?',
  ]),
  _SentenceSeed('¿A qué hora abre la tienda?', '가게는 몇 시에 열어요?', [
    '¿A qué hora',
    'abre',
    'la tienda?',
  ]),
  _SentenceSeed('¿Dónde está el baño?', '화장실은 어디예요?', [
    '¿Dónde está',
    'el baño?',
  ]),
  _SentenceSeed('¿Puedo pagar con tarjeta?', '카드로 결제할 수 있나요?', [
    '¿Puedo',
    'pagar',
    'con tarjeta?',
  ]),
  _SentenceSeed('Deme un recibo, por favor.', '영수증을 주세요.', [
    'Deme',
    'un recibo,',
    'por favor.',
  ]),
  _SentenceSeed('Tengo una alergia alimentaria.', '음식 알레르기가 있어요.', [
    'Tengo',
    'una alergia alimentaria.',
  ]),
  _SentenceSeed('Llame a una ambulancia, por favor.', '구급차를 불러 주세요.', [
    'Llame',
    'a una ambulancia,',
    'por favor.',
  ]),
  _SentenceSeed('He perdido mi pasaporte.', '여권을 잃어버렸어요.', [
    'He perdido',
    'mi pasaporte.',
  ]),
  _SentenceSeed('¿Hay wifi aquí?', '여기에 와이파이가 있나요?', ['¿Hay', 'wifi', 'aquí?']),
  _SentenceSeed('La reunión empieza a las diez.', '회의는 열 시에 시작해요.', [
    'La reunión',
    'empieza',
    'a las diez.',
  ]),
  _SentenceSeed('Envíeme el archivo, por favor.', '파일을 보내 주세요.', [
    'Envíeme',
    'el archivo,',
    'por favor.',
  ]),
  _SentenceSeed('Le devolveré la llamada más tarde.', '나중에 다시 전화할게요.', [
    'Le devolveré',
    'la llamada',
    'más tarde.',
  ]),
  _SentenceSeed('Necesito más tiempo.', '시간이 더 필요해요.', [
    'Necesito',
    'más tiempo.',
  ]),
  _SentenceSeed('¿Podría repetirlo, por favor?', '다시 말해 주시겠어요?', [
    '¿Podría',
    'repetirlo,',
    'por favor?',
  ]),
  _SentenceSeed('¿Cómo se escribe esto?', '이건 철자가 어떻게 되나요?', [
    '¿Cómo',
    'se escribe',
    'esto?',
  ]),
  _SentenceSeed('¿Qué significa esta palabra?', '이 단어는 무슨 뜻이에요?', [
    '¿Qué significa',
    'esta palabra?',
  ]),
  _SentenceSeed('Hoy he estudiado durante treinta minutos.', '오늘 30분 공부했어요.', [
    'Hoy',
    'he estudiado',
    'durante treinta minutos.',
  ]),
];

const _chinesePracticalSentences = <_SentenceSeed>[
  _SentenceSeed('我想办理入住。', '체크인하고 싶어요.', [
    '我想',
    '办理入住。',
  ], reading: 'wǒ xiǎng bàn lǐ rù zhù'),
  _SentenceSeed('可以看看菜单吗？', '메뉴를 볼 수 있을까요?', [
    '可以',
    '看看',
    '菜单吗？',
  ], reading: 'kě yǐ kàn kan cài dān ma'),
  _SentenceSeed('请送我到这个地址。', '이 주소로 데려다 주세요.', [
    '请',
    '送我到',
    '这个地址。',
  ], reading: 'qǐng sòng wǒ dào zhè ge dì zhǐ'),
  _SentenceSeed('这趟火车去市中心吗？', '이 기차는 시내로 가나요?', [
    '这趟火车',
    '去',
    '市中心吗？',
  ], reading: 'zhè tàng huǒ chē qù shì zhōng xīn ma'),
  _SentenceSeed('商店几点开门？', '가게는 몇 시에 열어요?', [
    '商店',
    '几点',
    '开门？',
  ], reading: 'shāng diàn jǐ diǎn kāi mén'),
  _SentenceSeed('洗手间在哪里？', '화장실은 어디예요?', [
    '洗手间',
    '在哪里？',
  ], reading: 'xǐ shǒu jiān zài nǎ lǐ'),
  _SentenceSeed('可以刷卡吗？', '카드로 결제할 수 있나요?', [
    '可以',
    '刷卡吗？',
  ], reading: 'kě yǐ shuā kǎ ma'),
  _SentenceSeed('请给我收据。', '영수증을 주세요.', [
    '请',
    '给我',
    '收据。',
  ], reading: 'qǐng gěi wǒ shōu jù'),
  _SentenceSeed('我对这种食物过敏。', '음식 알레르기가 있어요.', [
    '我对',
    '这种食物',
    '过敏。',
  ], reading: 'wǒ duì zhè zhǒng shí wù guò mǐn'),
  _SentenceSeed('请叫救护车。', '구급차를 불러 주세요.', [
    '请',
    '叫',
    '救护车。',
  ], reading: 'qǐng jiào jiù hù chē'),
  _SentenceSeed('我的护照丢了。', '여권을 잃어버렸어요.', [
    '我的护照',
    '丢了。',
  ], reading: 'wǒ de hù zhào diū le'),
  _SentenceSeed('这里有无线网络吗？', '여기에 와이파이가 있나요?', [
    '这里有',
    '无线网络吗？',
  ], reading: 'zhè lǐ yǒu wú xiàn wǎng luò ma'),
  _SentenceSeed('会议十点开始。', '회의는 열 시에 시작해요.', [
    '会议',
    '十点',
    '开始。',
  ], reading: 'huì yì shí diǎn kāi shǐ'),
  _SentenceSeed('请把文件发给我。', '파일을 보내 주세요.', [
    '请把',
    '文件',
    '发给我。',
  ], reading: 'qǐng bǎ wén jiàn fā gěi wǒ'),
  _SentenceSeed('我晚一点给你回电话。', '나중에 다시 전화할게요.', [
    '我晚一点',
    '给你',
    '回电话。',
  ], reading: 'wǒ wǎn yì diǎn gěi nǐ huí diàn huà'),
  _SentenceSeed('我需要更多时间。', '시간이 더 필요해요.', [
    '我需要',
    '更多时间。',
  ], reading: 'wǒ xū yào gèng duō shí jiān'),
  _SentenceSeed('请再说一遍。', '다시 한번 말해 주세요.', [
    '请',
    '再说',
    '一遍。',
  ], reading: 'qǐng zài shuō yí biàn'),
  _SentenceSeed('这个怎么写？', '이것은 어떻게 쓰나요?', [
    '这个',
    '怎么写？',
  ], reading: 'zhè ge zěn me xiě'),
  _SentenceSeed('这个词是什么意思？', '이 단어는 무슨 뜻이에요?', [
    '这个词',
    '是',
    '什么意思？',
  ], reading: 'zhè ge cí shì shén me yì si'),
  _SentenceSeed(
    '我今天练习了三十分钟。',
    '오늘 30분 연습했어요.',
    ['我今天', '练习了', '三十分钟。'],
    reading: 'wǒ jīn tiān liàn xí le sān shí fēn zhōng',
  ),
];
