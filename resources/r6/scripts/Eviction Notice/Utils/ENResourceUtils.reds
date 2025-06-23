// -----------------------------------------------------------------------------
// ENJournalUtils
// -----------------------------------------------------------------------------
//
// - Does special handling of SMS messages when rendered in order to
//   live-update whether or not certain Phone Choice Entries should be
//   displayed.
// - Updates base game Journal entries in-place when the journal resources
//   are loaded in order to clear conditions on an MQ055 player choice that
//   is critical for allowing the player to decline a romantic hangout.
// - Grabs references to Eviction Notice journal entries that need to later
//   be marked Unread.
//

module EvictionNotice.Utils

import EvictionNotice.Settings.ENSettings
import EvictionNotice.Gameplay.{
    ENRentState,
    ENRentSystemBase,
    ENRentSystemMBH10,
    ENRentSystemNorthside,
    ENRentSystemJapantown,
    ENRentSystemGlen,
    ENRentSystemCorpoPlaza,
    ENBillPaySystem
}
import EvictionNotice.Services.ENPropertyStateService

public struct ENInternetPageDatum {
    private let page: ref<JournalInternetPage>;
    private let indexToReplace: Int32;
}

// JournalEntriesListController
// Catch romance hangout SMS choices and prevent them from being selected if a property is not available. 
//
@wrapMethod(JournalEntriesListController)
public final func PushEntries(const data: script_ref<array<wref<JournalEntry>>>) -> Void {
    let entries: array<wref<JournalEntry>> = Deref(data);
    let rentSystem: ref<ENRentSystemBase>;
    
    for entry in entries {
        let id = entry.GetId();

        // Base Game - MQ055
        // Eviction Notice - EZEstates Move Out
        if Equals(id, "01_06a_v_megabuilding") || Equals(id, "02_03a_v_megabuilding") || Equals(id, "MoveOutSelect_H10") {
            // Check Megabuilding H10 Rent State
            rentSystem = ENRentSystemMBH10.Get();
            if !rentSystem.IsCurrentRentStateRented() {
                ArrayRemove(entries, entry);
            }
            
        } else if Equals(id, "01_06b_v_northside") || Equals(id, "02_03b_v_northside") || Equals(id, "MoveOutSelect_Northside") {
            // Check Northside Rent State
            rentSystem = ENRentSystemNorthside.Get();
            if !rentSystem.IsCurrentRentStateRented() {
                ArrayRemove(entries, entry);
            }

        } else if Equals(id, "01_06c_v_japantown") || Equals(id, "02_03c_v_japantown") || Equals(id, "MoveOutSelect_Japantown") {
            // Check Japantown Rent State
            rentSystem = ENRentSystemJapantown.Get();
            if !rentSystem.IsCurrentRentStateRented() {
                ArrayRemove(entries, entry);
            }

        } else if Equals(id, "01_06d_v_heywood") || Equals(id, "02_03d_v_heywood") || Equals(id, "MoveOutSelect_Glen") {
            // Check Glen Rent State
            rentSystem = ENRentSystemGlen.Get();
            if !rentSystem.IsCurrentRentStateRented() {
                ArrayRemove(entries, entry);
            }

        } else if Equals(id, "01_06e_v_downtown") || Equals(id, "02_03e_v_downtown") || Equals(id, "MoveOutSelect_CorpoPlaza") {
            // Check Corpo Plaza Rent State
            rentSystem = ENRentSystemCorpoPlaza.Get();
            if !rentSystem.IsCurrentRentStateRented() {
                ArrayRemove(entries, entry);
            }
        
        // Eviction Notice - EZEstates Player Root - Move Out
        } else if Equals(id, "MoveOutSelect_MoveOut") || Equals(id, "MoveOutSelect_MoveOutRepeat") || Equals(id, "RentCycleTimeLeft") {
            // Check that player has at least one property
            if ENPropertyStateService.Get().GetRentedPropertyCount() == 0u {
                ArrayRemove(entries, entry);
            }

        // Eviction Notice - EZEstates Player Root - Auto Pay
        } else if Equals(id, "AutoPayEnable") {
            // Check if Auto Pay is already enabled
            if ENBillPaySystem.Get().IsAutoPayEnabled() {
                ArrayRemove(entries, entry);
            }

        } else if Equals(id, "AutoPayDisable") {
            // Check if Auto Pay is already disabled
            if !ENBillPaySystem.Get().IsAutoPayEnabled() {
                ArrayRemove(entries, entry);
            }
        }
    }

    wrappedMethod(entries);
}

public class ENResourceHandler extends ScriptableService {
    let mq055choices: array<ref<JournalPhoneChoiceEntry>>;
    let apartmentPageData: array<ENInternetPageDatum>;
    let repeatableMessages: array<ref<JournalPhoneMessage>>;
    let apartmentWebPages: array<String>;

    public final static func GetInstance(gameInstance: GameInstance) -> ref<ENResourceHandler> {
		let instance: ref<ENResourceHandler> = GameInstance.GetScriptableServiceContainer().GetService(NameOf(ENResourceHandler)) as ENResourceHandler;
		return instance;
	}

	public final static func Get() -> ref<ENResourceHandler> {
		return ENResourceHandler.GetInstance(GetGameInstance());
	}

    private cb func OnLoad() {
        this.apartmentWebPages = [
            "01_apart_wat_nid2", 
            "01_apart_wat_nid1",
            "01_apart_wat_nid3",
            "01_apart_wat_nid4",
            "01_apart_wat_nid9",
            "01_apart_wat_nid7",
            "01_apart_wat_nid6",
            "01_apart_wat_nid14",
            "01_apart_wat_nid15",
            "01_apart_wat_nid5",
            "01_apart_wat_nid11",
            "01_apart_wat_nid12"
        ];

        // Journal - Parse Journal Entries
        GameInstance.GetCallbackSystem().RegisterCallback(n"Resource/PostLoad", this, n"ProcessJournal")
        .AddTarget(ResourceTarget.Type(n"gameJournalResource"));

        // Journal - Apply Journal Changes
        GameInstance.GetCallbackSystem().RegisterCallback(n"Session/Ready", this, n"OnSessionReady");
    }

    private cb func OnSessionReady(event: ref<GameSessionEvent>) {
        // Update the MQ055 Refuse choices so that they can always be selected.
        for choice in this.mq055choices {
            choice.questCondition = null;
        }
    }

    public final func GetRepeatableMessages() -> array<ref<JournalPhoneMessage>> {
        return this.repeatableMessages;
    }

    // TODO: Test against website framework mod
    private final func SetEZEstatesWebsiteOnApartmentComputer(pageDatum: ENInternetPageDatum) -> Void {
        let image: ref<JournalInternetImage> = new JournalInternetImage();
        image.linkAddress = "NETdir://ezestates.web/for_rent";
        let siteIndexID: Int32 = pageDatum.indexToReplace + 1;
        let siteIndexAsString: String = siteIndexID < 10 ? "0" + ToString(siteIndexID) : ToString(siteIndexID);
        image.name = StringToName("ImageLink" + siteIndexAsString);
        let imageTextureAtlas: ResourceAsyncRef;
        ResourceAsyncRef.SetPath(imageTextureAtlas, r"base\\gameplay\\gui\\world\\internet\\templates\\atlases\\icons_atlas.inkatlas");
        image.textureAtlas = imageTextureAtlas;
        image.texturePart = n"EZestate";

        pageDatum.page.images[pageDatum.indexToReplace] = image;

        let internetText: ref<JournalInternetText> = new JournalInternetText();
        internetText.linkAddress = "NETdir://ezestates.web/for_rent";
        internetText.name = StringToName("TextLink" + siteIndexAsString);
        internetText.text = CreateLocalizationString("LocKey#80750");

        pageDatum.page.texts[pageDatum.indexToReplace] = internetText;
    }

    private cb func ProcessJournal(event: ref<ResourceEvent>) {
        let journalResource = event.GetResource() as gameJournalResource;
        if IsDefined(journalResource) {
            let rootFolder = this.FindRootFolder(journalResource);
            if IsDefined(rootFolder) {
                let contacts = this.FindPrimaryFolder(rootFolder, "contacts");
                if IsDefined(contacts) {
                    // Base Game
                    let judyContact = this.FindContact(contacts, "judy");
                    let riverContact = this.FindContact(contacts, "river_ward");
                    let panamContact = this.FindContact(contacts, "panam");
                    let kerryContact = this.FindContact(contacts, "kerry_eurodyne");

                    // Eviction Notice
                    let billpayContact = this.FindContact(contacts, "en_williamsmgmt");
                    
                    if IsDefined(judyContact) {
                        this.StoreMQ055ChoiceForContact(judyContact);
                    }

                    if IsDefined(riverContact) {
                        this.StoreMQ055ChoiceForContact(riverContact);
                    }

                    if IsDefined(panamContact) {
                        this.StoreMQ055ChoiceForContact(panamContact);
                    }

                    if IsDefined(kerryContact) {
                        this.StoreMQ055ChoiceForContact(kerryContact);
                    }

                    if IsDefined(billpayContact) {
                        this.StoreRepeatableBillPayMessages(billpayContact);
                    }
                }

                // Add EZEstates website to home pages accessible in other apartments
                let internetSites = this.FindPrimaryFolder(rootFolder, "internet_sites");
                if IsDefined(internetSites) {
                    let homePage = this.FindInternetSite(internetSites, "home");

                    if IsDefined(homePage) {
                        // Megabuilding H10 - Handled by Base Game
                        let northsideHomePage = this.FindInternetPage(homePage, "00_home_01_watson");
                        let glenJapantownHomePage = this.FindInternetPage(homePage, "00_home");
                        let corpoPlazaHomePage = this.FindInternetPage(homePage, "00_home_02_center");

                        if IsDefined(northsideHomePage) {
                            let pageDatum: ENInternetPageDatum;
                            pageDatum.page = northsideHomePage;
                            pageDatum.indexToReplace = 9; // Replace "Arasaka" Site
                            ArrayPush(this.apartmentPageData, pageDatum);
                        }

                        if IsDefined(glenJapantownHomePage) {
                            let pageDatum: ENInternetPageDatum;
                            pageDatum.page = glenJapantownHomePage;
                            pageDatum.indexToReplace = 9; // Takes up empty 10th spot
                            ArrayPush(this.apartmentPageData, pageDatum);
                        }

                        if IsDefined(corpoPlazaHomePage) {
                            let pageDatum: ENInternetPageDatum;
                            pageDatum.page = corpoPlazaHomePage;
                            pageDatum.indexToReplace = 3; // Replace "Execution Time" Site
                            ArrayPush(this.apartmentPageData, pageDatum);
                        }
                    }

                    // Add text entries to each site for populating the Deposit and Rent Amount
                    let apartmentsSite = this.FindInternetSite(internetSites, "apartments");
                    if IsDefined(apartmentsSite) {
                        for apartmentWebPage in this.apartmentWebPages {
                            this.AddPriceTextEntriesToSite(apartmentsSite, apartmentWebPage);
                        }
                    }
                }
            }
        }

        // Set up EZEstates website on all apartment computer terminals.
        for pageDatum in this.apartmentPageData {
            this.SetEZEstatesWebsiteOnApartmentComputer(pageDatum);
        }
    }

    private final func AddPriceTextEntriesToSite(site: ref<JournalInternetSite>, pageId: String) -> Void {
        let page: ref<JournalInternetPage> = this.FindInternetPage(site, pageId);
        if IsDefined(page) {
            let rentAmountText: ref<JournalInternetText> = new JournalInternetText();
            rentAmountText.name = n"ENRentAmount";

            let depositAmountText: ref<JournalInternetText> = new JournalInternetText();
            depositAmountText.name = n"ENDepositAmount";

            ArrayPush(page.texts, rentAmountText);
            ArrayPush(page.texts, depositAmountText);
        }
    }

    private final func StoreMQ055ChoiceForContact(contact: ref<JournalContact>) -> Void {
        let mq055Convo = this.FindPhoneConversation(contact, "mq055_invite");
        if IsDefined(mq055Convo) { 
            let targetChoiceGroup = this.FindPhoneChoiceGroup(mq055Convo, "01_06_ch_apartment");
            if IsDefined(targetChoiceGroup) {
                let choice = this.FindPhoneChoiceEntry(targetChoiceGroup, "01_06g_v_refuse");
                if IsDefined(choice) {
                    ArrayPush(this.mq055choices, choice);
                }
            }

            targetChoiceGroup = this.FindPhoneChoiceGroup(mq055Convo, "01_06b_ch_apartment");
            if IsDefined(targetChoiceGroup) {
                let choice = this.FindPhoneChoiceEntry(targetChoiceGroup, "01_06g_v_refuse");
                if IsDefined(choice) {
                    ArrayPush(this.mq055choices, choice);
                }
            }

            targetChoiceGroup = this.FindPhoneChoiceGroup(mq055Convo, "02_03_ch_apartment");
            if IsDefined(targetChoiceGroup) {
                let choice = this.FindPhoneChoiceEntry(targetChoiceGroup, "02_03g_v_refuse");
                if IsDefined(choice) {
                    ArrayPush(this.mq055choices, choice);
                }
            }

            targetChoiceGroup = this.FindPhoneChoiceGroup(mq055Convo, "02_03b_ch_apartment");
            if IsDefined(targetChoiceGroup) {
                let choice = this.FindPhoneChoiceEntry(targetChoiceGroup, "02_03g_v_refuse");
                if IsDefined(choice) {
                    ArrayPush(this.mq055choices, choice);
                }
            }
        }
    }

    private final func StoreRepeatableBillPayMessages(contact: ref<JournalContact>) -> Void {
        let updateConvo = this.FindPhoneConversation(contact, "02_updates");
        let paymentConvo = this.FindPhoneConversation(contact, "03_payment");
        let reminderConvo = this.FindPhoneConversation(contact, "04_reminder");

        if IsDefined(updateConvo) {
            this.GetAllPhoneMessagesForConversation(updateConvo, this.repeatableMessages);
        }

        if IsDefined(paymentConvo) {
            this.GetAllPhoneMessagesForConversation(paymentConvo, this.repeatableMessages);
        }

        if IsDefined(reminderConvo) {
            this.GetAllPhoneMessagesForConversation(reminderConvo, this.repeatableMessages);
        }
    }

    private final func FindRootFolder(journalResource: ref<gameJournalResource>) -> ref<gameJournalRootFolderEntry> {
        return journalResource.entry as gameJournalRootFolderEntry;
    }

    private final func FindPrimaryFolder(rootFolder: ref<gameJournalRootFolderEntry>, id: String) -> ref<gameJournalPrimaryFolderEntry> {
        let primaryFolders = rootFolder.entries;
        let foundFolder: ref<gameJournalPrimaryFolderEntry>;
        for primaryFolder in primaryFolders {
            if Equals(primaryFolder.id, id) {
                //FTLog("FindPrimaryFolder: Found " + id);
                foundFolder = primaryFolder as gameJournalPrimaryFolderEntry;
                break;
            }
        }

        return foundFolder;
    }

    private final func FindContact(primaryFolder: ref<gameJournalPrimaryFolderEntry>, id: String) -> ref<JournalContact> {
        let contactEntries = primaryFolder.entries;
        let foundContact: ref<JournalContact>;
        for contactEntry in contactEntries {
            if Equals(contactEntry.id, id) {
                //FTLog("FindContact: Found " + id);
                foundContact = contactEntry as JournalContact;
                break;
            }
        }

        return foundContact;
    }

    private final func FindPhoneConversation(contact: ref<JournalContact>, id: String) -> ref<JournalPhoneConversation> {
        let conversations = contact.entries;
        let foundConversation: ref<JournalPhoneConversation>;
        for conversation in conversations {
            if Equals(conversation.id, id) {
                //FTLog("FindPhoneConversation: Found " + id);
                foundConversation = conversation as JournalPhoneConversation;
                break;
            }
        }

        return foundConversation;
    }

    private final func FindPhoneChoiceGroup(conversation: ref<JournalPhoneConversation>, id: String) -> ref<JournalPhoneChoiceGroup> {
        let groups = conversation.entries;
        let foundGroup: ref<JournalPhoneChoiceGroup>;
        for group in groups {
            if Equals(group.id, id) {
                //FTLog("FindPhoneChoiceGroup: Found " + id);
                foundGroup = group as JournalPhoneChoiceGroup;
                break;
            }
        }

        return foundGroup;
    }

    private final func FindPhoneChoiceEntry(choiceGroup: ref<JournalPhoneChoiceGroup>, id: String) -> ref<JournalPhoneChoiceEntry> {
        let choices = choiceGroup.entries;
        let foundChoice: ref<JournalPhoneChoiceEntry>;
        for choice in choices {
            //FTLog("FindPhoneChoiceEntry: condition is " + ToString((choice as JournalPhoneChoiceEntry).questCondition));
            if Equals(choice.id, id) {
                //FTLog("FindPhoneChoiceEntry: Found " + id);
                foundChoice = choice as JournalPhoneChoiceEntry;
                break;
            }
        }

        return foundChoice;
    }

    private final func FindInternetSite(primaryFolder: ref<gameJournalPrimaryFolderEntry>, id: String) -> ref<JournalInternetSite> {
        let internetSiteEntries = primaryFolder.entries;
        let foundSite: ref<JournalInternetSite>;
        for internetSiteEntry in internetSiteEntries {
            if Equals(internetSiteEntry.id, id) {
                FTLog("FindInternetSite: Found " + id);
                foundSite = internetSiteEntry as JournalInternetSite;
                break;
            }
        }

        return foundSite;
    }

    private final func FindInternetPage(site: ref<JournalInternetSite>, id: String) -> ref<JournalInternetPage> {
        let internetPageEntries = site.entries;
        let foundPage: ref<JournalInternetPage>;
        for internetPageEntry in internetPageEntries {
            if Equals(internetPageEntry.id, id) {
                //FTLog("FindInternetPage: Found " + id);
                foundPage = internetPageEntry as JournalInternetPage;
                break;
            }
        }

        return foundPage;
    }

    private final func GetAllPhoneMessagesForConversation(conversation: ref<JournalPhoneConversation>, out repeatableMessages: array<ref<JournalPhoneMessage>>) -> Void {
        let messages = conversation.entries;
        for message in messages {
            //FTLog("Adding to repeatable messages list: " + ToString(message.id));
            ArrayPush(repeatableMessages, message as JournalPhoneMessage);
        }
    }
}

@addMethod(WebPage)
private final func ENGetDepositAmountForPage(pageId: String) -> Int32 {
    switch pageId {
        case "01_apart_wat_nid2":
        case "01_apart_wat_nid1":
        case "01_apart_wat_nid3":
            return ENRentSystemNorthside.Get().GetSecurityDepositAmount();

        case "01_apart_wat_nid4":
        case "01_apart_wat_nid9":
        case "01_apart_wat_nid7":
            return ENRentSystemJapantown.Get().GetSecurityDepositAmount();

        case "01_apart_wat_nid6":
        case "01_apart_wat_nid14":
        case "01_apart_wat_nid15":
            return ENRentSystemGlen.Get().GetSecurityDepositAmount();

        case "01_apart_wat_nid5":
        case "01_apart_wat_nid11":
        case "01_apart_wat_nid12":
            return ENRentSystemCorpoPlaza.Get().GetSecurityDepositAmount();

        default:
            return 0;
    }

    return 0;
}

@addMethod(WebPage)
private final func ENGetRentalAmountForPage(pageId: String) -> Int32 {
    switch pageId {
        case "01_apart_wat_nid2":
        case "01_apart_wat_nid1":
        case "01_apart_wat_nid3":
            return ENRentSystemNorthside.Get().GetRentAmount();

        case "01_apart_wat_nid4":
        case "01_apart_wat_nid9":
        case "01_apart_wat_nid7":
            return ENRentSystemJapantown.Get().GetRentAmount();

        case "01_apart_wat_nid6":
        case "01_apart_wat_nid14":
        case "01_apart_wat_nid15":
            return ENRentSystemGlen.Get().GetRentAmount();

        case "01_apart_wat_nid5":
        case "01_apart_wat_nid11":
        case "01_apart_wat_nid12":
            return ENRentSystemCorpoPlaza.Get().GetRentAmount();

        default:
            return 0;
    }

    return 0;
}

// WebPage - Because the standard method of text replacement using Wolvenkit-constructed widgets does not currently seem to work
// (the copied textList handle is invalid), use another method to replace the text on the page by targeting the widget.
//
@wrapMethod(WebPage)
private final func FillPageFromJournal(page: wref<JournalInternetPage>) -> Void {
    wrappedMethod(page);

    let depositAmountTextWidget: ref<inkText> = this.GetRootCompoundWidget().GetWidget(n"Page/offer/city_center/ENDepositAmount") as inkText;
    let rentalAmountTextWidget: ref<inkText> = this.GetRootCompoundWidget().GetWidget(n"Page/offer/city_center/ENRentAmount") as inkText;
    
    let texts: array<ref<JournalInternetText>> = page.GetTexts();
    let i: Int32 = 0;
    while i < ArraySize(texts) {
        let instanceName: CName = texts[i].GetName();

        if Equals(instanceName, n"ENDepositAmount") {
            let depositAmount: Int32 = this.ENGetDepositAmountForPage(page.id);
            let depositAmountString: String = GetLocalizedTextByKey(n"EvictionNoticeWebPageDepositAmount");
            let depositAmountStringUpdated: String = StrReplaceAll(depositAmountString, "{EN_ALIAS_WEBPAGE_DEPOSIT_AMOUNT}", ToString(depositAmount));

            if IsDefined(depositAmountTextWidget) {
                depositAmountTextWidget.SetText(depositAmountStringUpdated);
            }

        } else if Equals(instanceName, n"ENRentAmount") {
            let rentAmount: Int32 = this.ENGetRentalAmountForPage(page.id);
            let rentAmountString: String = GetLocalizedTextByKey(n"EvictionNoticeWebPageRentAmount");
            let rentAmountStringUpdated: String = StrReplaceAll(StrReplaceAll(rentAmountString, "{EN_ALIAS_WEBPAGE_RENT_AMOUNT}", ToString(rentAmount)), "{EN_ALIAS_WEBPAGE_RENT_PERIOD}", ToString(ENSettings.Get().rentalPeriodInDays));

            if IsDefined(rentalAmountTextWidget) {
                rentalAmountTextWidget.SetText(rentAmountStringUpdated);
            }
        }
        i += 1;
    }
}