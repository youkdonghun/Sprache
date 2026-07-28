import 'language.dart';

class CourseNoteExample {
  const CourseNoteExample({required this.target, required this.korean});

  final String target;
  final String korean;
}

class CourseNote {
  const CourseNote({
    required this.title,
    required this.summary,
    required this.pattern,
    required this.patternMeaning,
    required this.examples,
    required this.usageTip,
    required this.soundTip,
  });

  final String title;
  final String summary;
  final String pattern;
  final String patternMeaning;
  final List<CourseNoteExample> examples;
  final String usageTip;
  final String soundTip;
}

CourseNote courseNoteFor(LanguageTag language, int unitIndex) {
  final notes = _courseNotes[language]!;
  RangeError.checkValidIndex(unitIndex, notes, 'unitIndex');
  return notes[unitIndex];
}

final Map<LanguageTag, List<CourseNote>> _courseNotes = {
  LanguageTag.english: const [
    CourseNote(
      title: '이름과 상태를 말하는 be동사',
      summary: '처음 만난 사람에게 이름과 현재 상태를 짧게 전합니다.',
      pattern: 'I am … / My name is …',
      patternMeaning: '저는 …입니다 / 제 이름은 …입니다',
      examples: [
        CourseNoteExample(target: 'I am Minjun.', korean: '저는 민준입니다.'),
        CourseNoteExample(
          target: 'My name is Sora. Nice to meet you.',
          korean: '제 이름은 소라예요. 만나서 반가워요.',
        ),
      ],
      usageTip:
          'I am은 대화에서 주로 I’m으로 줄입니다. 이름 뒤에 Nice to meet you를 붙이면 자연스럽습니다.',
      soundTip: 'I’m은 두 단어를 끊지 말고 한 덩어리처럼 말해 보세요.',
    ),
    CourseNote(
      title: '사람을 소개하고 소유를 말하기',
      summary: '가까운 사람을 가리키고 내가 가진 것을 설명합니다.',
      pattern: 'This is … / I have …',
      patternMeaning: '이 사람은 …입니다 / 저는 …이 있습니다',
      examples: [
        CourseNoteExample(
          target: 'This is my friend, Alex.',
          korean: '이쪽은 제 친구 알렉스예요.',
        ),
        CourseNoteExample(
          target: 'I have two sisters.',
          korean: '저는 자매가 두 명 있어요.',
        ),
      ],
      usageTip: '사람을 직접 소개할 때는 He is보다 This is가 더 자연스럽습니다.',
      soundTip: 'this의 th는 혀끝을 앞니 사이에 가볍게 두고 소리 냅니다.',
    ),
    CourseNote(
      title: '시간을 붙여 하루 일과 말하기',
      summary: '현재형 동사에 시간을 더해 반복되는 일과를 표현합니다.',
      pattern: 'I + verb … at + time',
      patternMeaning: '저는 …시에 …합니다',
      examples: [
        CourseNoteExample(
          target: 'I wake up at seven.',
          korean: '저는 7시에 일어나요.',
        ),
        CourseNoteExample(
          target: 'I study English in the evening.',
          korean: '저는 저녁에 영어를 공부해요.',
        ),
      ],
      usageTip: '정확한 시각 앞에는 at, 아침·오후·저녁 앞에는 in을 씁니다.',
      soundTip: 'at seven은 끝 자음과 다음 단어를 자연스럽게 이어 말해 보세요.',
    ),
    CourseNote(
      title: '공손하게 주문하기',
      summary: '원하는 것을 단정적으로 요구하지 않고 부드럽게 부탁합니다.',
      pattern: 'I’d like … / Can I have …?',
      patternMeaning: '…을 원합니다 / …을 받을 수 있을까요?',
      examples: [
        CourseNoteExample(
          target: 'I’d like a coffee, please.',
          korean: '커피 한 잔 주세요.',
        ),
        CourseNoteExample(
          target: 'Can I have the menu?',
          korean: '메뉴를 받을 수 있을까요?',
        ),
      ],
      usageTip: '주문에서는 I want보다 I’d like가 더 부드럽습니다. 끝에 please를 붙여도 좋습니다.',
      soundTip: 'I’d like는 “아이드 라이크”처럼 이어지며 d를 과하게 강조하지 않습니다.',
    ),
    CourseNote(
      title: '장소와 이동 방법 묻기',
      summary: '목적지의 위치와 그곳까지 가는 방법을 확인합니다.',
      pattern: 'Where is …? / How do I get to …?',
      patternMeaning: '…은 어디예요? / …에는 어떻게 가요?',
      examples: [
        CourseNoteExample(target: 'Where is the station?', korean: '역은 어디예요?'),
        CourseNoteExample(
          target: 'How do I get to the airport?',
          korean: '공항에는 어떻게 가요?',
        ),
      ],
      usageTip: '장소 이름 앞의 the는 station, airport처럼 특정 시설을 가리킬 때 자주 씁니다.',
      soundTip: 'Where is는 실제 대화에서 두 단어가 거의 붙어 들립니다.',
    ),
    CourseNote(
      title: '이해하지 못했을 때 다시 부탁하기',
      summary: '대화를 포기하지 않고 반복이나 도움을 정중하게 요청합니다.',
      pattern: 'Could you …? / I don’t understand.',
      patternMeaning: '…해 주시겠어요? / 이해하지 못했어요',
      examples: [
        CourseNoteExample(
          target: 'Could you say that again?',
          korean: '다시 말씀해 주시겠어요?',
        ),
        CourseNoteExample(
          target: 'I don’t understand. Please speak slowly.',
          korean: '이해하지 못했어요. 천천히 말씀해 주세요.',
        ),
      ],
      usageTip: '명령형보다 Could you를 쓰면 낯선 사람에게도 정중하게 들립니다.',
      soundTip: 'don’t의 마지막 t는 약해질 수 있지만 부정 의미는 분명하게 전달하세요.',
    ),
  ],
  LanguageTag.japanese: const [
    CourseNote(
      title: 'です로 정중하게 소개하기',
      summary: '이름 뒤에 です를 붙여 처음 만난 사람에게 자신을 소개합니다.',
      pattern: 'わたしは … です / … といいます',
      patternMeaning: '저는 …입니다 / …라고 합니다',
      examples: [
        CourseNoteExample(target: 'わたしはミナです。', korean: '저는 미나입니다.'),
        CourseNoteExample(
          target: 'キムといいます。はじめまして。',
          korean: '김이라고 합니다. 처음 뵙겠습니다.',
        ),
      ],
      usageTip: '상황상 주어가 분명하면 わたしは는 자주 생략합니다.',
      soundTip: 'です의 す는 문장 끝에서 아주 약하게 들리는 경우가 많습니다.',
    ),
    CourseNote(
      title: 'は와 が로 사람과 존재 말하기',
      summary: '화제는 は로, 사람이나 사물의 존재는 がいます·あります로 표현합니다.',
      pattern: '… は … です / … が います',
      patternMeaning: '…은 …입니다 / …이 있습니다',
      examples: [
        CourseNoteExample(target: 'こちらは友だちです。', korean: '이쪽은 제 친구입니다.'),
        CourseNoteExample(target: '兄が一人います。', korean: '형이 한 명 있습니다.'),
      ],
      usageTip: '사람·동물의 존재에는 います, 사물에는 あります를 씁니다.',
      soundTip: '조사 は는 글자는 “하”지만 이때는 “와”로 읽습니다.',
    ),
    CourseNote(
      title: 'ます형으로 일과 말하기',
      summary: '동사의 ます형과 시간 표현으로 정중하게 하루를 설명합니다.',
      pattern: '… 時に … ます',
      patternMeaning: '…시에 …합니다',
      examples: [
        CourseNoteExample(target: '七時に起きます。', korean: '7시에 일어납니다.'),
        CourseNoteExample(target: '毎日日本語を勉強します。', korean: '매일 일본어를 공부합니다.'),
      ],
      usageTip: '정확한 시각 뒤에는 に를 쓰지만 今日·毎日 같은 말 뒤에는 보통 に를 쓰지 않습니다.',
      soundTip: 'ます의 す도 문장 끝에서 약해지지만 리듬은 유지하세요.',
    ),
    CourseNote(
      title: 'ください로 주문하기',
      summary: '원하는 음식이나 물건 뒤에 をください를 붙여 부탁합니다.',
      pattern: '… を ください / … を お願いします',
      patternMeaning: '…을 주세요 / …을 부탁합니다',
      examples: [
        CourseNoteExample(target: 'コーヒーを一つください。', korean: '커피 하나 주세요.'),
        CourseNoteExample(target: 'メニューをお願いします。', korean: '메뉴 부탁합니다.'),
      ],
      usageTip: '가게에서는 품목 뒤에 수량 표현을 넣으면 더 정확합니다.',
      soundTip: 'ください는 “쿠다사이” 네 박자를 고르게 말해 보세요.',
    ),
    CourseNote(
      title: 'どこ와 で로 위치·이동 말하기',
      summary: '장소는 どこですか로 묻고 이동 수단은 で로 표시합니다.',
      pattern: '… は どこですか / … で 行きます',
      patternMeaning: '…은 어디입니까? / …을 타고 갑니다',
      examples: [
        CourseNoteExample(target: '駅はどこですか。', korean: '역은 어디입니까?'),
        CourseNoteExample(target: '電車で空港へ行きます。', korean: '전철로 공항에 갑니다.'),
      ],
      usageTip: '이동 수단 뒤에는 で, 방향을 나타내는 목적지 뒤에는 へ를 쓸 수 있습니다.',
      soundTip: '방향 조사 へ는 이때 “에”로 읽습니다.',
    ),
    CourseNote(
      title: '다시 말해 달라고 부탁하기',
      summary: '이해가 어려울 때 정중한 고정 표현으로 대화를 이어갑니다.',
      pattern: 'もう一度お願いします / わかりません',
      patternMeaning: '한 번 더 부탁합니다 / 모르겠습니다',
      examples: [
        CourseNoteExample(target: 'もう一度お願いします。', korean: '한 번 더 부탁합니다.'),
        CourseNoteExample(
          target: 'わかりません。ゆっくり話してください。',
          korean: '모르겠습니다. 천천히 말해 주세요.',
        ),
      ],
      usageTip: '상대의 말을 못 들었을 때는 すみません을 앞에 붙이면 더 부드럽습니다.',
      soundTip: 'もう는 길게 늘여 한 박자가 아니라 두 박자로 말합니다.',
    ),
  ],
  LanguageTag.german: const [
    CourseNote(
      title: 'heißen과 sein으로 자기소개하기',
      summary: '이름은 heißen, 국적이나 상태는 sein으로 말합니다.',
      pattern: 'Ich heiße … / Ich bin …',
      patternMeaning: '제 이름은 …입니다 / 저는 …입니다',
      examples: [
        CourseNoteExample(target: 'Ich heiße Mina.', korean: '제 이름은 미나입니다.'),
        CourseNoteExample(
          target: 'Ich bin Student. Freut mich.',
          korean: '저는 학생입니다. 반갑습니다.',
        ),
      ],
      usageTip: '직업을 말할 때는 보통 Student 앞에 부정관사를 붙이지 않습니다.',
      soundTip: 'ich의 ch는 “ㅋ”보다 혀를 입천장 가까이 둔 부드러운 마찰음입니다.',
    ),
    CourseNote(
      title: 'Das ist와 haben으로 소개하기',
      summary: '사람을 가리켜 소개하고 가족이나 소유를 표현합니다.',
      pattern: 'Das ist … / Ich habe …',
      patternMeaning: '이 사람은 …입니다 / 저는 …이 있습니다',
      examples: [
        CourseNoteExample(
          target: 'Das ist mein Freund.',
          korean: '이 사람은 제 친구입니다.',
        ),
        CourseNoteExample(
          target: 'Ich habe eine Schwester.',
          korean: '저는 자매가 한 명 있습니다.',
        ),
      ],
      usageTip: '명사의 성에 따라 mein·meine, ein·eine 형태가 달라집니다.',
      soundTip: 'ist의 t를 짧게 닫고 다음 단어로 넘어가세요.',
    ),
    CourseNote(
      title: '동사 2위 규칙으로 일과 말하기',
      summary: '평서문에서 활용된 동사는 문장 성분과 관계없이 두 번째 자리에 옵니다.',
      pattern: 'Ich + Verb … / Um … Uhr + Verb + ich …',
      patternMeaning: '저는 …합니다 / …시에 저는 …합니다',
      examples: [
        CourseNoteExample(
          target: 'Ich stehe um sieben Uhr auf.',
          korean: '저는 7시에 일어납니다.',
        ),
        CourseNoteExample(
          target: 'Am Abend lerne ich Deutsch.',
          korean: '저녁에 저는 독일어를 공부합니다.',
        ),
      ],
      usageTip: '시간을 문장 앞에 두면 동사 다음에 주어가 옵니다.',
      soundTip: 'Uhr의 r은 강하게 굴리기보다 모음처럼 약해질 수 있습니다.',
    ),
    CourseNote(
      title: 'möchte로 부드럽게 주문하기',
      summary: 'Ich möchte를 써서 원하는 음식과 음료를 정중하게 주문합니다.',
      pattern: 'Ich möchte … / …, bitte',
      patternMeaning: '저는 …을 원합니다 / … 부탁합니다',
      examples: [
        CourseNoteExample(
          target: 'Ich möchte einen Kaffee, bitte.',
          korean: '커피 한 잔 주세요.',
        ),
        CourseNoteExample(
          target: 'Die Speisekarte, bitte.',
          korean: '메뉴판 부탁합니다.',
        ),
      ],
      usageTip: '주문 대상의 격과 성에 따라 einen·eine·ein 형태가 달라집니다.',
      soundTip: 'möchte의 ö는 입술을 둥글게 하고 “에”에 가까운 소리를 냅니다.',
    ),
    CourseNote(
      title: 'Wo와 이동 수단 말하기',
      summary: 'Wo ist로 위치를 묻고 mit로 이동 수단을 표현합니다.',
      pattern: 'Wo ist …? / Ich fahre mit …',
      patternMeaning: '…은 어디입니까? / 저는 …을 타고 갑니다',
      examples: [
        CourseNoteExample(target: 'Wo ist der Bahnhof?', korean: '기차역은 어디입니까?'),
        CourseNoteExample(
          target: 'Ich fahre mit dem Bus.',
          korean: '저는 버스를 타고 갑니다.',
        ),
      ],
      usageTip: 'mit 뒤에는 3격이 와서 der Bus가 dem Bus로 바뀝니다.',
      soundTip: 'Bahnhof의 첫 음절을 더 강하게 말합니다.',
    ),
    CourseNote(
      title: 'Können Sie로 도움 요청하기',
      summary: '낯선 사람에게 Sie를 사용해 반복과 도움을 정중하게 부탁합니다.',
      pattern: 'Können Sie …? / Ich verstehe nicht.',
      patternMeaning: '…해 주실 수 있나요? / 이해하지 못했습니다',
      examples: [
        CourseNoteExample(
          target: 'Können Sie das wiederholen?',
          korean: '그것을 반복해 주실 수 있나요?',
        ),
        CourseNoteExample(
          target: 'Ich verstehe nicht. Bitte langsam.',
          korean: '이해하지 못했습니다. 천천히 부탁합니다.',
        ),
      ],
      usageTip: '친한 사이의 du가 아니라 공손한 Sie를 쓸 때는 대문자로 적습니다.',
      soundTip: 'Können의 ö와 두 음절 리듬을 살려 말해 보세요.',
    ),
  ],
  LanguageTag.french: const [
    CourseNote(
      title: 's’appeler와 être로 소개하기',
      summary: '이름과 신분을 프랑스어의 기본 동사로 표현합니다.',
      pattern: 'Je m’appelle … / Je suis …',
      patternMeaning: '제 이름은 …입니다 / 저는 …입니다',
      examples: [
        CourseNoteExample(target: 'Je m’appelle Mina.', korean: '제 이름은 미나입니다.'),
        CourseNoteExample(
          target: 'Je suis coréen. Enchanté.',
          korean: '저는 한국인입니다. 반갑습니다.',
        ),
      ],
      usageTip: 'Enchanté는 화자의 성에 따라 표기상 Enchantée가 될 수 있지만 발음은 같습니다.',
      soundTip: 'Je의 j는 영어의 “ㅈ”보다 부드럽게 마찰시킵니다.',
    ),
    CourseNote(
      title: 'C’est와 avoir로 소개하기',
      summary: '사람을 소개하고 가족이나 소유를 말합니다.',
      pattern: 'C’est … / J’ai …',
      patternMeaning: '이 사람은 …입니다 / 저는 …이 있습니다',
      examples: [
        CourseNoteExample(target: 'C’est mon ami.', korean: '이 사람은 제 친구입니다.'),
        CourseNoteExample(target: 'J’ai un frère.', korean: '저는 형제 한 명이 있습니다.'),
      ],
      usageTip: '모음 앞에서 Je ai가 아니라 J’ai로 줄여 씁니다.',
      soundTip: 'C’est는 한 음절처럼 짧게 말합니다.',
    ),
    CourseNote(
      title: '현재형과 시간 표현',
      summary: '현재형 동사와 à를 사용해 반복되는 하루 일과를 말합니다.',
      pattern: 'Je + verbe … à + heure',
      patternMeaning: '저는 …시에 …합니다',
      examples: [
        CourseNoteExample(
          target: 'Je me lève à sept heures.',
          korean: '저는 7시에 일어납니다.',
        ),
        CourseNoteExample(
          target: 'J’étudie le français le soir.',
          korean: '저는 저녁에 프랑스어를 공부합니다.',
        ),
      ],
      usageTip: '정확한 시각 앞에는 à, 반복되는 요일이나 시간대에는 관사가 자주 쓰입니다.',
      soundTip: 'sept heures에서는 끝 자음과 다음 모음이 이어져 들릴 수 있습니다.',
    ),
    CourseNote(
      title: 'Je voudrais로 주문하기',
      summary: '조건법 형태를 사용해 원하는 것을 공손하게 부탁합니다.',
      pattern: 'Je voudrais … / …, s’il vous plaît',
      patternMeaning: '…을 원합니다 / … 부탁합니다',
      examples: [
        CourseNoteExample(
          target: 'Je voudrais un café, s’il vous plaît.',
          korean: '커피 한 잔 부탁합니다.',
        ),
        CourseNoteExample(
          target: 'La carte, s’il vous plaît.',
          korean: '메뉴판 부탁합니다.',
        ),
      ],
      usageTip: 'Je veux보다 Je voudrais가 주문 상황에서 훨씬 부드럽습니다.',
      soundTip: 'voudrais의 마지막 s는 발음하지 않습니다.',
    ),
    CourseNote(
      title: 'Où와 aller로 위치·이동 말하기',
      summary: '장소의 위치를 묻고 목적지로 가는 일을 표현합니다.',
      pattern: 'Où est …? / Je vais à …',
      patternMeaning: '…은 어디입니까? / 저는 …에 갑니다',
      examples: [
        CourseNoteExample(target: 'Où est la gare ?', korean: '기차역은 어디입니까?'),
        CourseNoteExample(
          target: 'Je vais à l’aéroport en bus.',
          korean: '저는 버스로 공항에 갑니다.',
        ),
      ],
      usageTip: '도시·장소 앞에는 à, 교통수단에는 en이나 à가 수단에 따라 달라집니다.',
      soundTip: 'Où는 입술을 둥글게 한 “우” 소리입니다.',
    ),
    CourseNote(
      title: 'Pouvez-vous로 도움 요청하기',
      summary: 'vous 형태로 반복이나 천천히 말하기를 정중하게 요청합니다.',
      pattern: 'Pouvez-vous …? / Je ne comprends pas.',
      patternMeaning: '…해 주실 수 있나요? / 이해하지 못합니다',
      examples: [
        CourseNoteExample(
          target: 'Pouvez-vous répéter ?',
          korean: '다시 말해 주실 수 있나요?',
        ),
        CourseNoteExample(
          target: 'Je ne comprends pas. Parlez lentement, s’il vous plaît.',
          korean: '이해하지 못합니다. 천천히 말해 주세요.',
        ),
      ],
      usageTip: '구어에서는 ne가 약해지기도 하지만 초급 단계에서는 ne … pas를 함께 익히세요.',
      soundTip: 'comprends의 끝 자음은 대부분 소리 내지 않습니다.',
    ),
  ],
  LanguageTag.spanish: const [
    CourseNote(
      title: 'llamarse와 ser로 자기소개하기',
      summary: '이름과 신분을 말하고 처음 만난 사람에게 인사합니다.',
      pattern: 'Me llamo … / Soy …',
      patternMeaning: '제 이름은 …입니다 / 저는 …입니다',
      examples: [
        CourseNoteExample(target: 'Me llamo Mina.', korean: '제 이름은 미나입니다.'),
        CourseNoteExample(
          target: 'Soy estudiante. Mucho gusto.',
          korean: '저는 학생입니다. 만나서 반갑습니다.',
        ),
      ],
      usageTip: '스페인어는 동사 형태에 주어가 드러나므로 Yo를 자주 생략합니다.',
      soundTip: 'll의 발음은 지역에 따라 “이” 또는 부드러운 “ㅈ”처럼 들릴 수 있습니다.',
    ),
    CourseNote(
      title: 'Este·Esta와 tener로 소개하기',
      summary: '사람을 소개하고 가족이나 소유를 표현합니다.',
      pattern: 'Este/Esta es … / Tengo …',
      patternMeaning: '이 사람은 …입니다 / 저는 …이 있습니다',
      examples: [
        CourseNoteExample(
          target: 'Esta es mi amiga.',
          korean: '이 사람은 제 여자 친구입니다.',
        ),
        CourseNoteExample(
          target: 'Tengo dos hermanos.',
          korean: '저는 형제가 두 명 있습니다.',
        ),
      ],
      usageTip: '가리키는 명사의 성에 따라 Este와 Esta를 구분합니다.',
      soundTip: 'tengo의 g는 e 앞에서도 이 단어에서는 단단한 “ㄱ” 소리입니다.',
    ),
    CourseNote(
      title: '현재형과 시각 말하기',
      summary: '현재형 동사와 a las를 사용해 하루 일과의 시각을 말합니다.',
      pattern: 'Verbo … a la/a las + hora',
      patternMeaning: '…시에 …합니다',
      examples: [
        CourseNoteExample(
          target: 'Me levanto a las siete.',
          korean: '저는 7시에 일어납니다.',
        ),
        CourseNoteExample(
          target: 'Estudio español por la noche.',
          korean: '저는 밤에 스페인어를 공부합니다.',
        ),
      ],
      usageTip: '1시는 a la una, 2시 이상은 a las dos처럼 복수를 씁니다.',
      soundTip: '모음은 짧아져도 음가가 크게 변하지 않도록 또렷하게 말하세요.',
    ),
    CourseNote(
      title: 'Quisiera로 주문하기',
      summary: '원하는 음식이나 물건을 공손한 표현으로 부탁합니다.',
      pattern: 'Quisiera … / …, por favor',
      patternMeaning: '…을 원합니다 / … 부탁합니다',
      examples: [
        CourseNoteExample(
          target: 'Quisiera un café, por favor.',
          korean: '커피 한 잔 부탁합니다.',
        ),
        CourseNoteExample(target: 'La carta, por favor.', korean: '메뉴판 부탁합니다.'),
      ],
      usageTip: 'Quiero도 가능하지만 Quisiera가 서비스 상황에서 더 부드럽습니다.',
      soundTip: 'qui는 “키”로 읽고 u는 따로 소리 내지 않습니다.',
    ),
    CourseNote(
      title: 'Dónde와 ir로 위치·이동 말하기',
      summary: '목적지의 위치와 이동 수단을 질문하고 설명합니다.',
      pattern: '¿Dónde está …? / Voy a … en …',
      patternMeaning: '…은 어디에 있나요? / 저는 …을 타고 …에 갑니다',
      examples: [
        CourseNoteExample(
          target: '¿Dónde está la estación?',
          korean: '역은 어디에 있나요?',
        ),
        CourseNoteExample(
          target: 'Voy al aeropuerto en autobús.',
          korean: '저는 버스로 공항에 갑니다.',
        ),
      ],
      usageTip: 'a + el은 al로 합쳐 씁니다.',
      soundTip: 'Dónde의 강세는 첫 음절에 있습니다.',
    ),
    CourseNote(
      title: 'Puede로 정중하게 도움 요청하기',
      summary: '상대에게 반복이나 천천히 말하기를 공손하게 부탁합니다.',
      pattern: '¿Puede …? / No entiendo.',
      patternMeaning: '…해 주실 수 있나요? / 이해하지 못합니다',
      examples: [
        CourseNoteExample(
          target: '¿Puede repetirlo?',
          korean: '그것을 다시 말해 주실 수 있나요?',
        ),
        CourseNoteExample(
          target: 'No entiendo. Hable más despacio, por favor.',
          korean: '이해하지 못합니다. 더 천천히 말해 주세요.',
        ),
      ],
      usageTip: '낯선 사람에게는 tú형 puedes보다 usted형 puede가 더 공손합니다.',
      soundTip: 'h는 발음하지 않으므로 hable은 모음으로 시작하는 것처럼 말합니다.',
    ),
  ],
  LanguageTag.simplifiedChinese: const [
    CourseNote(
      title: '叫와 是로 자기소개하기',
      summary: '이름은 叫, 신분은 是를 사용해 간결하게 소개합니다.',
      pattern: '我叫… / 我是…',
      patternMeaning: '제 이름은 …입니다 / 저는 …입니다',
      examples: [
        CourseNoteExample(target: '我叫敏俊。', korean: '제 이름은 민준입니다.'),
        CourseNoteExample(
          target: '我是韩国人。很高兴认识你。',
          korean: '저는 한국인입니다. 만나서 반가워요.',
        ),
      ],
      usageTip: '叫 뒤에는 이름을 바로 붙이고 是 뒤에는 국적·직업 같은 신분을 둡니다.',
      soundTip: '我 wǒ는 3성이며 단독 연습 후 다음 음절과 이어 말해 보세요.',
    ),
    CourseNote(
      title: '这와 有로 소개·소유 말하기',
      summary: '사람을 소개하고 가족이나 가지고 있는 것을 표현합니다.',
      pattern: '这是… / 我有…',
      patternMeaning: '이 사람은 …입니다 / 저는 …이 있습니다',
      examples: [
        CourseNoteExample(target: '这是我的朋友。', korean: '이 사람은 제 친구입니다.'),
        CourseNoteExample(target: '我有一个妹妹。', korean: '저는 여동생이 한 명 있습니다.'),
      ],
      usageTip: '수량을 말할 때 숫자와 명사 사이에 个 같은 양사를 넣습니다.',
      soundTip: '这是 zhè shì는 두 음절 모두 4성이어서 분명히 떨어뜨려 말합니다.',
    ),
    CourseNote(
      title: '시간을 동사 앞에 놓기',
      summary: '중국어는 보통 주어 뒤, 동사 앞에 시간 표현을 둡니다.',
      pattern: '主语 + 时间 + 动词',
      patternMeaning: '주어 + 시간 + 동작',
      examples: [
        CourseNoteExample(target: '我七点起床。', korean: '저는 7시에 일어납니다.'),
        CourseNoteExample(target: '我晚上学习中文。', korean: '저는 저녁에 중국어를 공부합니다.'),
      ],
      usageTip: '시각 뒤에 별도의 조사를 붙이지 않고 동사 앞에 바로 놓습니다.',
      soundTip: '七点 qī diǎn의 성조가 각각 1성·3성임을 확인하세요.',
    ),
    CourseNote(
      title: '要와 请给我로 주문하기',
      summary: '원하는 것을 직접 말하거나 请을 붙여 공손하게 부탁합니다.',
      pattern: '我要… / 请给我…',
      patternMeaning: '저는 …을 원합니다 / 저에게 …을 주세요',
      examples: [
        CourseNoteExample(target: '我要一杯咖啡。', korean: '커피 한 잔 주세요.'),
        CourseNoteExample(target: '请给我菜单。', korean: '메뉴판을 주세요.'),
      ],
      usageTip: '음료에는 一杯처럼 알맞은 양사를 함께 쓰면 자연스럽습니다.',
      soundTip: '请 qǐng은 3성, 给 gěi도 3성이므로 이어 말할 때 첫 3성은 올라갈 수 있습니다.',
    ),
    CourseNote(
      title: '在哪儿와 坐로 위치·이동 말하기',
      summary: '장소의 위치를 묻고 타는 교통수단을 동사 坐로 표현합니다.',
      pattern: '…在哪儿？ / 坐…去…',
      patternMeaning: '…은 어디에 있나요? / …을 타고 …에 갑니다',
      examples: [
        CourseNoteExample(target: '车站在哪儿？', korean: '정류장이나 역은 어디에 있나요?'),
        CourseNoteExample(target: '我坐地铁去机场。', korean: '저는 지하철을 타고 공항에 갑니다.'),
      ],
      usageTip: '중국 북부에서는 哪儿, 남부권과 표준 교재에서는 哪里도 자주 씁니다.',
      soundTip: '哪儿 nǎr의 r은 앞 음절 끝에 가볍게 붙습니다.',
    ),
    CourseNote(
      title: '请으로 반복과 도움 요청하기',
      summary: '못 들었거나 이해하지 못했을 때 정중하게 다시 요청합니다.',
      pattern: '请再说一遍 / 我不明白',
      patternMeaning: '다시 한 번 말해 주세요 / 이해하지 못합니다',
      examples: [
        CourseNoteExample(target: '请再说一遍。', korean: '다시 한 번 말해 주세요.'),
        CourseNoteExample(
          target: '我不明白，请说慢一点。',
          korean: '이해하지 못합니다. 조금 천천히 말해 주세요.',
        ),
      ],
      usageTip: '请을 문장 앞에 붙이면 부탁이 부드러워집니다.',
      soundTip: '一遍은 이 표현에서 yí biàn처럼 성조가 변해 들립니다.',
    ),
  ],
};
