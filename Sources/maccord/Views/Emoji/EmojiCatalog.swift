import Foundation

/// A curated, searchable unicode emoji catalog grouped into Discord-style
/// categories. Not exhaustive, but broad enough to feel real; custom guild emoji
/// are added on top by the picker.
enum EmojiCatalog {
    struct Entry: Identifiable, Hashable {
        let char: String
        let name: String
        var id: String { char }
    }
    struct Category: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let entries: [Entry]
    }

    static let categories: [Category] = [
        Category(id: "smileys", title: "Smileys & People", symbol: "face.smiling", entries: people),
        Category(id: "nature", title: "Animals & Nature", symbol: "leaf", entries: nature),
        Category(id: "food", title: "Food & Drink", symbol: "fork.knife", entries: food),
        Category(id: "activities", title: "Activities", symbol: "soccerball", entries: activities),
        Category(id: "travel", title: "Travel & Places", symbol: "car.fill", entries: travel),
        Category(id: "objects", title: "Objects", symbol: "lightbulb", entries: objects),
        Category(id: "symbols", title: "Symbols", symbol: "heart.fill", entries: symbols),
        Category(id: "flags", title: "Flags", symbol: "flag.fill", entries: flags),
    ]

    static func search(_ query: String) -> [Entry] {
        let q = query.lowercased()
        return categories.flatMap(\.entries).filter { $0.name.contains(q) }
    }

    private static func e(_ c: String, _ n: String) -> Entry { Entry(char: c, name: n) }

    static let people: [Entry] = [
        e("😀","grinning"), e("😃","smiley"), e("😄","smile"), e("😁","grin"), e("😆","laughing"),
        e("😅","sweat smile"), e("🤣","rofl"), e("😂","joy tears laugh"), e("🙂","slight smile"),
        e("🙃","upside down"), e("😉","wink"), e("😊","blush"), e("😇","innocent angel"),
        e("🥰","smiling hearts love"), e("😍","heart eyes love"), e("🤩","star struck"),
        e("😘","kiss"), e("😗","kissing"), e("😚","kissing closed"), e("😋","yum"),
        e("😛","tongue"), e("😜","wink tongue"), e("🤪","zany"), e("😝","squint tongue"),
        e("🤑","money mouth"), e("🤗","hug"), e("🤭","hand over mouth"), e("🤫","shush quiet"),
        e("🤔","thinking"), e("🤐","zipper mouth"), e("🤨","raised eyebrow"), e("😐","neutral"),
        e("😑","expressionless"), e("😶","no mouth"), e("😏","smirk"), e("😒","unamused"),
        e("🙄","eye roll"), e("😬","grimace"), e("🤥","lying"), e("😌","relieved"),
        e("😔","pensive"), e("😪","sleepy"), e("🤤","drooling"), e("😴","sleeping zzz"),
        e("😷","mask sick"), e("🤒","thermometer sick"), e("🤕","head bandage hurt"),
        e("🥵","hot heat"), e("🥶","cold freezing"), e("😵","dizzy"), e("🤯","mind blown"),
        e("🤠","cowboy"), e("🥳","party celebrate"), e("😎","cool sunglasses"), e("🤓","nerd"),
        e("🧐","monocle"), e("😕","confused"), e("😟","worried"), e("🙁","frown"),
        e("😮","open mouth wow"), e("😯","hushed"), e("😲","astonished shock"), e("😳","flushed"),
        e("🥺","pleading puppy"), e("😦","frowning"), e("😨","fearful"), e("😰","anxious sweat"),
        e("😥","sad relieved"), e("😢","cry"), e("😭","sob crying"), e("😱","scream"),
        e("😖","confounded"), e("😣","persevere"), e("😞","disappointed"), e("😓","sweat"),
        e("😩","weary"), e("😫","tired"), e("😤","triumph steam"), e("😡","rage angry"),
        e("😠","angry"), e("🤬","cursing swearing"), e("😈","smiling devil"), e("👿","imp angry devil"),
        e("💀","skull dead"), e("💩","poop"), e("🤡","clown"), e("👻","ghost"), e("👽","alien"),
        e("🤖","robot"), e("🎃","jack o lantern pumpkin"),
        e("👍","thumbs up like yes"), e("👎","thumbs down dislike no"), e("👌","ok"),
        e("🤌","pinched"), e("✌️","victory peace"), e("🤞","fingers crossed"), e("🤟","love you"),
        e("🤘","rock on"), e("👈","point left"), e("👉","point right"), e("👆","point up"),
        e("👇","point down"), e("☝️","index up"), e("✋","raised hand stop"), e("🤚","back hand"),
        e("🖐️","hand fingers"), e("🖖","vulcan"), e("👋","wave hi hello bye"), e("🤙","call me"),
        e("💪","muscle flex strong"), e("🙏","pray thanks please"), e("👏","clap"), e("🙌","raised hands praise"),
        e("👐","open hands"), e("🤝","handshake"), e("✊","fist"), e("👊","punch fist bump"),
        e("❤️","red heart love"), e("🧡","orange heart"), e("💛","yellow heart"), e("💚","green heart"),
        e("💙","blue heart"), e("💜","purple heart"), e("🖤","black heart"), e("🤍","white heart"),
        e("💔","broken heart"), e("💕","two hearts"), e("💖","sparkling heart"), e("💯","hundred perfect"),
        e("🔥","fire lit"), e("⭐","star"), e("🌟","glowing star"), e("✨","sparkles"),
    ]

    static let nature: [Entry] = [
        e("🐶","dog puppy"), e("🐱","cat"), e("🐭","mouse"), e("🐹","hamster"), e("🐰","rabbit bunny"),
        e("🦊","fox"), e("🐻","bear"), e("🐼","panda"), e("🐨","koala"), e("🐯","tiger"),
        e("🦁","lion"), e("🐮","cow"), e("🐷","pig"), e("🐸","frog"), e("🐵","monkey"),
        e("🐔","chicken"), e("🐧","penguin"), e("🐦","bird"), e("🐤","baby chick"), e("🦆","duck"),
        e("🦅","eagle"), e("🦉","owl"), e("🐺","wolf"), e("🐗","boar"), e("🐴","horse"),
        e("🦄","unicorn"), e("🐝","bee"), e("🐛","bug"), e("🦋","butterfly"), e("🐌","snail"),
        e("🐞","ladybug"), e("🐢","turtle"), e("🐍","snake"), e("🐙","octopus"), e("🦑","squid"),
        e("🦐","shrimp"), e("🐠","fish"), e("🐬","dolphin"), e("🐳","whale"), e("🦈","shark"),
        e("🌸","cherry blossom"), e("🌹","rose"), e("🌻","sunflower"), e("🌲","tree evergreen"),
        e("🌴","palm tree"), e("🌵","cactus"), e("🍀","clover luck"), e("🍁","maple leaf"),
        e("🌍","earth globe"), e("🌙","moon"), e("☀️","sun"), e("⛅","cloud sun"), e("🌧️","rain"),
        e("⛄","snowman"), e("❄️","snowflake"), e("🌈","rainbow"), e("💧","droplet water"),
    ]

    static let food: [Entry] = [
        e("🍎","apple"), e("🍐","pear"), e("🍊","orange tangerine"), e("🍋","lemon"), e("🍌","banana"),
        e("🍉","watermelon"), e("🍇","grapes"), e("🍓","strawberry"), e("🍑","peach"), e("🥭","mango"),
        e("🍍","pineapple"), e("🥥","coconut"), e("🥝","kiwi"), e("🍅","tomato"), e("🥑","avocado"),
        e("🍆","eggplant"), e("🥔","potato"), e("🥕","carrot"), e("🌽","corn"), e("🌶️","pepper spicy"),
        e("🥒","cucumber"), e("🥬","lettuce"), e("🥦","broccoli"), e("🍄","mushroom"), e("🥜","peanut"),
        e("🍞","bread"), e("🥐","croissant"), e("🥖","baguette"), e("🥨","pretzel"), e("🧀","cheese"),
        e("🥚","egg"), e("🍳","fried egg"), e("🥞","pancakes"), e("🥓","bacon"), e("🍔","burger"),
        e("🍟","fries"), e("🍕","pizza"), e("🌭","hot dog"), e("🥪","sandwich"), e("🌮","taco"),
        e("🌯","burrito"), e("🥗","salad"), e("🍝","spaghetti pasta"), e("🍜","ramen noodles"),
        e("🍣","sushi"), e("🍤","shrimp tempura"), e("🍦","ice cream"), e("🍩","donut"),
        e("🍪","cookie"), e("🎂","birthday cake"), e("🍰","cake"), e("🍫","chocolate"),
        e("🍬","candy"), e("🍭","lollipop"), e("🍿","popcorn"), e("☕","coffee"), e("🍵","tea"),
        e("🍺","beer"), e("🍻","beers cheers"), e("🥂","champagne cheers"), e("🍷","wine"),
        e("🍸","cocktail"), e("🥤","soda drink"),
    ]

    static let activities: [Entry] = [
        e("⚽","soccer football"), e("🏀","basketball"), e("🏈","american football"), e("⚾","baseball"),
        e("🎾","tennis"), e("🏐","volleyball"), e("🏉","rugby"), e("🎱","8 ball pool"), e("🏓","ping pong"),
        e("🏸","badminton"), e("🥅","goal"), e("🏒","hockey"), e("🏑","field hockey"), e("🥍","lacrosse"),
        e("🏏","cricket"), e("⛳","golf"), e("🏹","bow archery"), e("🎣","fishing"), e("🥊","boxing"),
        e("🥋","martial arts"), e("⛸️","ice skate"), e("🎿","ski"), e("🛹","skateboard"), e("🏆","trophy win"),
        e("🥇","gold medal first"), e("🥈","silver medal"), e("🥉","bronze medal"), e("🎮","game controller"),
        e("🕹️","joystick"), e("🎲","dice"), e("🎯","dart bullseye target"), e("🎸","guitar"),
        e("🎹","piano keyboard"), e("🎺","trumpet"), e("🎻","violin"), e("🥁","drum"), e("🎤","mic"),
        e("🎧","headphones"), e("🎬","movie clapper"), e("🎨","art palette"), e("🎭","theatre"),
    ]

    static let travel: [Entry] = [
        e("🚗","car"), e("🚕","taxi"), e("🚙","suv"), e("🚌","bus"), e("🚎","trolley"), e("🏎️","race car"),
        e("🚓","police car"), e("🚑","ambulance"), e("🚒","fire truck"), e("🚚","truck"), e("🚜","tractor"),
        e("🛵","scooter"), e("🏍️","motorcycle"), e("🚲","bike bicycle"), e("✈️","plane"), e("🚀","rocket"),
        e("🛸","ufo"), e("🚁","helicopter"), e("⛵","sailboat"), e("🚤","speedboat"), e("🚢","ship"),
        e("⚓","anchor"), e("🚉","station"), e("🚆","train"), e("🚇","metro subway"), e("🗽","statue liberty"),
        e("🗼","tokyo tower"), e("🏰","castle"), e("🎡","ferris wheel"), e("🎢","roller coaster"),
        e("🏖️","beach"), e("🏔️","mountain"), e("🌋","volcano"), e("🏕️","camping"), e("🌆","city dusk"),
        e("🌃","night city"), e("🌉","bridge"), e("🎆","fireworks"),
    ]

    static let objects: [Entry] = [
        e("⌚","watch"), e("📱","phone mobile"), e("💻","laptop"), e("⌨️","keyboard"), e("🖥️","desktop computer"),
        e("🖨️","printer"), e("🖱️","mouse"), e("💽","disk"), e("💾","floppy save"), e("💿","cd"),
        e("📷","camera"), e("📸","camera flash"), e("🎥","movie camera"), e("📺","tv"), e("📻","radio"),
        e("☎️","telephone"), e("⏰","alarm clock"), e("⏳","hourglass"), e("📡","satellite"), e("🔋","battery"),
        e("🔌","plug"), e("💡","lightbulb idea"), e("🔦","flashlight"), e("🕯️","candle"), e("💸","money flying"),
        e("💵","dollar money"), e("💰","money bag"), e("💳","credit card"), e("💎","diamond gem"),
        e("⚖️","scales justice"), e("🔧","wrench"), e("🔨","hammer"), e("🛠️","tools"), e("⚙️","gear"),
        e("🔩","nut bolt"), e("🧲","magnet"), e("🔫","gun water"), e("💣","bomb"), e("🔪","knife"),
        e("🗡️","dagger sword"), e("🛡️","shield"), e("🚬","cigarette"), e("⚰️","coffin"), e("🔑","key"),
        e("🔒","lock"), e("🔓","unlock"), e("📌","pin"), e("📍","location pin"), e("📎","paperclip"),
        e("✂️","scissors"), e("🖊️","pen"), e("✏️","pencil"), e("📝","memo note"), e("📚","books"),
        e("📦","package box"), e("📬","mailbox"), e("✉️","envelope mail"), e("🔍","magnify search"),
        e("🔔","bell"), e("🔕","bell off mute"), e("📢","megaphone announce"), e("💊","pill medicine"),
    ]

    static let symbols: [Entry] = [
        e("✅","check mark yes"), e("❌","cross no x"), e("❎","negative check"), e("➕","plus"), e("➖","minus"),
        e("➗","divide"), e("✖️","multiply"), e("❓","question"), e("❗","exclamation"), e("‼️","double exclamation"),
        e("⁉️","interrobang"), e("💲","dollar"), e("💱","currency exchange"), e("™️","trademark"), e("©️","copyright"),
        e("®️","registered"), e("〰️","wavy dash"), e("➰","loop"), e("🔚","end"), e("🔙","back"),
        e("🔛","on"), e("🔝","top up"), e("🔜","soon"), e("⚠️","warning"), e("🚸","children crossing"),
        e("⛔","no entry"), e("🚫","prohibited no"), e("💢","anger"), e("♻️","recycle"), e("✔️","check"),
        e("☑️","ballot check"), e("🔘","radio button"), e("🔴","red circle"), e("🟠","orange circle"),
        e("🟡","yellow circle"), e("🟢","green circle"), e("🔵","blue circle"), e("🟣","purple circle"),
        e("⚫","black circle"), e("⚪","white circle"), e("🟥","red square"), e("🟩","green square"),
        e("🟦","blue square"), e("🔺","red triangle up"), e("🔻","red triangle down"), e("💠","diamond dot"),
        e("🔆","bright"), e("〽️","part alternation"), e("⚜️","fleur de lis"), e("🔱","trident"),
        e("♨️","hot springs"), e("🆗","ok button"), e("🆕","new"), e("🆒","cool"), e("🆓","free"),
        e("🆙","up"), e("🈵","full"), e("🎵","music note"), e("🎶","music notes"),
    ]

    static let flags: [Entry] = [
        e("🏁","checkered flag race"), e("🚩","triangular flag"), e("🏴","black flag"), e("🏳️","white flag"),
        e("🏳️‍🌈","rainbow pride flag"), e("🏴‍☠️","pirate flag"), e("🇺🇸","usa united states"),
        e("🇬🇧","uk united kingdom britain"), e("🇨🇦","canada"), e("🇫🇷","france"), e("🇩🇪","germany"),
        e("🇪🇸","spain"), e("🇮🇹","italy"), e("🇵🇹","portugal"), e("🇯🇵","japan"), e("🇨🇳","china"),
        e("🇰🇷","korea"), e("🇮🇳","india"), e("🇧🇷","brazil"), e("🇲🇽","mexico"), e("🇦🇺","australia"),
        e("🇷🇺","russia"), e("🇳🇱","netherlands"), e("🇸🇪","sweden"), e("🇨🇭","switzerland"), e("🇮🇪","ireland"),
    ]
}
