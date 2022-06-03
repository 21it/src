{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_HADDOCK show-extensions #-}

module RecklessTradingBot.Thread.TelegramBot
  ( apply,
  )
where

import qualified BitfinexClient.Chart as Chart
import Data.Maybe
import RecklessTradingBot.Import
import Telegram.Bot.API
import Telegram.Bot.API.InlineMode.InlineQueryResult
import Telegram.Bot.API.InlineMode.InputMessageContent
  ( defaultInputTextMessageContent,
  )
import Telegram.Bot.Simple
import Telegram.Bot.Simple.UpdateParser
  ( updateMessageSticker,
    updateMessageText,
  )

type Model = ()

data Action
  = InlineEcho InlineQueryId Text
  | StickerEcho InputFile ChatId
  | Echo Text

updateToAction :: Update -> Model -> Maybe Action
updateToAction update _
  | isJust $ updateInlineQuery update = do
    query <- updateInlineQuery update
    let queryId = inlineQueryId query
    let msg = inlineQueryQuery query
    Just $ InlineEcho queryId msg
  | isJust $ updateMessageSticker update = do
    fileId <- stickerFileId <$> updateMessageSticker update
    cid <- updateChatId update
    pure $ StickerEcho (InputFileId fileId) cid
  | otherwise = case updateMessageText update of
    Just text -> Just (Echo text)
    Nothing -> Nothing

handleAction :: Action -> Model -> Eff Action Model
handleAction action model = case action of
  InlineEcho queryId msg ->
    model <# do
      let result =
            InlineQueryResult
              InlineQueryResultArticle
              (InlineQueryResultId msg)
              (Just msg)
              (Just (defaultInputTextMessageContent msg))
              Nothing
          answerInlineQueryRequest =
            AnswerInlineQueryRequest
              { answerInlineQueryRequestInlineQueryId = queryId,
                answerInlineQueryRequestResults = [result],
                answerInlineQueryCacheTime = Nothing,
                answerInlineQueryIsPersonal = Nothing,
                answerInlineQueryNextOffset = Nothing,
                answerInlineQuerySwitchPmText = Nothing,
                answerInlineQuerySwitchPmParameter = Nothing
              }
      _ <- liftClientM (answerInlineQuery answerInlineQueryRequest)
      return ()
  StickerEcho file chat ->
    model <# do
      _ <-
        liftClientM
          ( sendSticker
              ( SendStickerRequest
                  (SomeChatId chat)
                  file
                  Nothing
                  Nothing
                  Nothing
                  Nothing
                  Nothing
              )
          )
      return ()
  Echo msg ->
    model <# do
      pure msg -- or replyText msg

teleJob ::
  ( MonadIO m
  ) =>
  UnliftIO m ->
  Model ->
  Eff Action Model
teleJob (UnliftIO run) =
  const
    . eff
    . liftIO
    $ run Chart.newExample

teleBot ::
  ( MonadIO m
  ) =>
  UnliftIO m ->
  BotApp Model Action
teleBot run =
  BotApp
    { botInitialModel = (),
      botAction = updateToAction,
      botHandler = handleAction,
      botJobs =
        [ BotJob
            { botJobSchedule = "* * * * *",
              botJobTask = teleJob run
            }
        ]
    }

apply :: (Env m) => m ()
apply = do
  $(logTM) DebugS "Spawned"
  --
  -- TODO : use Env class method
  --
  teleToken <- liftIO $ getEnvToken "TELEGRAM_BOT_TOKEN"
  teleEnv <- liftIO $ defaultTelegramClientEnv teleToken
  withUnliftIO $ \run ->
    startBot_ (teleBot run) teleEnv